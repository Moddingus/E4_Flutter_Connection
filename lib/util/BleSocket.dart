import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:core';
import 'dart:math';
import 'dart:typed_data';
import 'package:async/async.dart';
import 'package:quiver/async.dart';

// ignore_for_file: avoid_print
enum SubType {
  acc,
  bvp,
  gsr,
  ibi,
  tmp,
  bat,
  tag,
}
extension E4Matter on String {
  String e4mat() {
    return this + "\r\n";
  }
  List<dynamic> getDeviceList() {
    List a = [];
    String num_device = "";
    for (int i = 0; i < this.length; i++) {
      if (int.tryParse(this[i]) != null) {
        num_device += this[i];
      }
      if (this[i] == "|") {
        break;
      }

    }
    if (num_device == "") {
      return a;
    }
    for (int i = 1; i < int.parse(num_device) + 1; i++) {
      num count = 0;
      for (int j = 0; j < this.length; j++) {
        if (this[j] == "|") {
          count += 1;
        }
        if (count == i) {
          a.add(this.substring(j+2, j+8));
          break;
        }
      }
    }
    return a;
  }
  
}
extension EnumExtension on SubType {
  String getString() {
    return this.toString().substring(8, 11);
  }
}

class E4Packet {
  static E4Packet parse(String e) {
    throw UnimplementedError();
  }

  bool contains(String sub) {
    throw UnimplementedError();
  }

  bool isSysMessage() {
    throw UnimplementedError();
  }
}

class E4Device {
  final String btleAddr;

  E4Device(this.btleAddr);
}

class E4Measure {
  static E4Measure parse(E4Packet pkt) {
    throw UnimplementedError();
  }
}

class E4Error implements Exception {
  static E4Error from(E4Packet pkt) {
    throw UnimplementedError();
  }
}

class E4Socket {
  final _ctrl = StreamController<E4Measure>();
  final Socket _tx;
  late final StreamSubscription _sysMsgSub;
  late final StreamQueue<E4Packet> _rx;

  E4Socket._(this._tx) {
    final router = StreamRouter<E4Packet>(_tx
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .map((l) => E4Packet.parse(l)));
    final sysMessageStream = router.route((e4pkt) => e4pkt.isSysMessage());
    _sysMsgSub = sysMessageStream.listen((event) {
      _ctrl.addError(E4Error.from(event));
    });
    _rx = StreamQueue(router.defaultStream);
  }

  static Future<E4Socket> connect(String host, int port) async {
    final socket = await Socket.connect(host, port);
    return E4Socket._(socket);
  }

  Stream<E4Measure> subscribeToMeasure(String measureKind, E4Device device) {
    _tx.writeln("device_connect ${device.btleAddr}");
    final response = _rx.next;
    response.then((r) {
      if (r.contains("OK")) {
        _ctrl.addStream(_rx.rest.map((pkt) => E4Measure.parse(pkt)));
      } else {
        _ctrl.addError(E4Error());
      }
    });
    return _ctrl.stream;
  }

  void close() {
    _sysMsgSub.cancel();
    _ctrl.close();
    _tx.close();
  }
}
Future<void> main(List<String> arguments) async {
  final e4 = await E4Socket.connect('192.168.7.200', 12345);
  final stream = e4.subscribeToMeasure('gsr', E4Device('11:22:33:44'));
  stream.listen((event) {
    print("Received data : $event");
  });
}