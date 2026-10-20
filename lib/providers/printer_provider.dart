import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../services/thermal_receipt.dart';
import 'auth_provider.dart';
import 'session_provider.dart';

const thermalPrinterChannel = MethodChannel('exsha/thermal_printer');

class PrinterDevice {
  final String name;
  final String address;
  const PrinterDevice({required this.name, required this.address});
  factory PrinterDevice.fromMap(Map<dynamic, dynamic> map) => PrinterDevice(
    name: map['name'] as String? ?? 'Printer Bluetooth',
    address: map['address'] as String,
  );
}

class PrinterState {
  final PrinterDevice? selected;
  final List<PrinterDevice> devices;
  final int paperMm;
  final bool supported;
  final bool connected;
  final bool busy;
  final String? error;
  final bool uncertain;
  final String? message;
  final double printProgress;

  const PrinterState({
    this.selected,
    this.devices = const [],
    this.paperMm = 58,
    this.supported = true,
    this.connected = false,
    this.busy = false,
    this.error,
    this.uncertain = false,
    this.message,
    this.printProgress = 0,
  });

  PrinterState copyWith({
    PrinterDevice? selected,
    List<PrinterDevice>? devices,
    int? paperMm,
    bool? supported,
    bool? connected,
    bool? busy,
    String? error,
    bool? uncertain,
    String? message,
    bool clearFeedback = false,
    double? printProgress,
  }) => PrinterState(
    selected: selected ?? this.selected,
    devices: devices ?? this.devices,
    paperMm: paperMm ?? this.paperMm,
    supported: supported ?? this.supported,
    connected: connected ?? this.connected,
    busy: busy ?? this.busy,
    error: clearFeedback ? null : error ?? this.error,
    uncertain: uncertain ?? (clearFeedback ? false : this.uncertain),
    message: clearFeedback ? null : message ?? this.message,
    printProgress: printProgress ?? this.printProgress,
  );
}

class PrinterNotifier extends Notifier<PrinterState> {
  @override
  PrinterState build() {
    thermalPrinterChannel.setMethodCallHandler((call) async {
      if (call.method == 'statusChanged' && ref.mounted) {
        _acceptStatus(call.arguments as Map);
      } else if (call.method == 'writeProgress' && ref.mounted && state.busy) {
        final data = call.arguments as Map;
        final sent = data['sent'] as int;
        final total = data['total'] as int;
        if (total > 0 && sent >= 0 && sent <= total) {
          // shortcut: writes measure transfer; exact motor timing needs model-specific acknowledgements.
          final progress = (sent / total).clamp(0.0, .99);
          if (progress >= state.printProgress) {
            state = state.copyWith(printProgress: progress);
          }
        }
      }
    });
    ref.onDispose(() => thermalPrinterChannel.setMethodCallHandler(null));
    Future.microtask(refresh);
    return const PrinterState();
  }

  void _acceptStatus(Map<dynamic, dynamic> map) {
    if (!ref.mounted) return;
    state = state.copyWith(
      selected: map['address'] == null
          ? null
          : PrinterDevice(
              name: map['name'] as String? ?? 'Printer Bluetooth',
              address: map['address'] as String,
            ),
      paperMm: map['paperMm'] == 80 ? 80 : 58,
      supported: map['supported'] == true,
      connected: map['connected'] == true,
    );
  }

  Future<void> refresh() async {
    if (!ref.mounted || state.busy) return;
    try {
      _acceptStatus(
        await thermalPrinterChannel.invokeMapMethod<dynamic, dynamic>(
              'status',
            ) ??
            {},
      );
    } on MissingPluginException {
      if (ref.mounted) {
        state = state.copyWith(supported: false, connected: false);
      }
    } on PlatformException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(connected: false, error: e.message);
      }
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (state.busy) return false;
    state = state.copyWith(
      busy: true,
      clearFeedback: true,
      uncertain: state.uncertain,
    );
    try {
      ref.read(authProvider.notifier).requireUser();
      await action();
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          connected: false,
          error: e is PlatformException
              ? e.message ?? 'Printer tidak tersedia.'
              : e is AuthException
              ? e.message
              : e is StateError
              ? e.message.toString()
              : e is MissingPluginException
              ? 'Printer Bluetooth hanya tersedia pada aplikasi Android.'
              : 'Struk gagal diproses. Periksa printer dan coba lagi.',
        );
      }
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  Future<void> loadDevices() => _run(() async {
    final list =
        await thermalPrinterChannel.invokeListMethod<dynamic>('devices') ?? [];
    if (ref.mounted) {
      state = state.copyWith(
        devices: list.map((d) => PrinterDevice.fromMap(d as Map)).toList(),
      );
    }
    _acceptStatus(
      await thermalPrinterChannel.invokeMapMethod<dynamic, dynamic>('status') ??
          {},
    );
  });

  Future<bool> connect(PrinterDevice device) => _run(() async {
    _acceptStatus(
      await thermalPrinterChannel.invokeMapMethod<dynamic, dynamic>('connect', {
            'address': device.address,
          }) ??
          {},
    );
    if (!state.connected) {
      throw StateError(
        'Printer belum terhubung. Periksa daya dan jarak printer.',
      );
    }
  });

  Future<void> disconnect() => _run(() async {
    _acceptStatus(
      await thermalPrinterChannel.invokeMapMethod<dynamic, dynamic>(
            'disconnect',
          ) ??
          {},
    );
  });

  Future<void> setPaper(int paperMm) => _run(() async {
    if (paperMm != 58 && paperMm != 80) {
      throw ArgumentError('Invalid paper width');
    }
    _acceptStatus(
      await thermalPrinterChannel.invokeMapMethod<dynamic, dynamic>('paper', {
            'paperMm': paperMm,
          }) ??
          {},
    );
  });

  Future<void> openSettings({bool permissions = false}) async {
    try {
      await thermalPrinterChannel.invokeMethod<void>(
        permissions ? 'appSettings' : 'bluetoothSettings',
      );
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          error: 'Buka pengaturan Bluetooth atau izin aplikasi dari pengaturan Android.',
        );
      }
    }
  }

  Future<bool> printReceipt(TransactionRecord transaction) {
    return _print(() async {
      final user = ref.read(authProvider.notifier).requireUser();
      if (!user.isAdmin && transaction.cashierId != user.cashierCode) {
        throw StateError('Anda hanya dapat mencetak transaksi sendiri.');
      }
      return buildThermalReceipt(transaction, state.paperMm);
    });
  }

  Future<bool> printShift(String shiftId) => _print(() async {
    ref.read(authProvider.notifier).requireAdmin();
    final store = ref.read(sessionProvider);
    if (store.loading || store.error != null) {
      throw StateError('Data shift belum siap. Coba muat ulang.');
    }
    final shift = store.shifts.where((s) => s.id == shiftId).firstOrNull;
    if (shift == null || shift.isOpen) {
      throw StateError('Pilih shift yang sudah ditutup.');
    }
    return buildThermalShiftReport(shift, state.paperMm);
  }, document: 'ringkasan shift');

  Future<bool> printTest() => _print(() => buildThermalTest(state.paperMm));

  Future<bool> _print(
    Future<Uint8List> Function() render, {
    String document = 'struk',
  }) {
    return _run(() async {
      state = state.copyWith(printProgress: 0);
      final bytes = await render();
      final device = state.selected;
      if (device == null) throw StateError('Pilih printer terlebih dahulu.');
      _acceptStatus(
        await thermalPrinterChannel.invokeMapMethod<dynamic, dynamic>(
              'status',
            ) ??
            {},
      );
      if (!state.connected) {
        _acceptStatus(
          await thermalPrinterChannel.invokeMapMethod<dynamic, dynamic>(
                'connect',
                {'address': device.address},
              ) ??
              {},
        );
      }
      if (!state.connected) throw StateError('Printer belum terhubung.');
      try {
        await thermalPrinterChannel.invokeMethod<void>('write', {
          'bytes': bytes,
        });
      } catch (_) {
        if (ref.mounted) state = state.copyWith(uncertain: true);
        rethrow;
      }
      if (ref.mounted) {
        state = state.copyWith(
          message: 'Data $document terkirim. Periksa hasil cetak pada printer.',
          uncertain: false,
          printProgress: 1,
        );
      }
    });
  }
}

final printerProvider = NotifierProvider<PrinterNotifier, PrinterState>(
  PrinterNotifier.new,
);
