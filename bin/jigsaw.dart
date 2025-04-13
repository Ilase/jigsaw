import 'dart:convert';

import 'package:jigsaw/data/j_logger.dart';
import 'package:jigsaw/domain/api/api_service.dart';
import 'package:jigsaw/domain/api/config.dart';
import 'package:jigsaw/domain/api/jwt/jwt_auth.dart';
import 'package:jigsaw/domain/db_service/db_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

void main(List<String> args) async {
  ///Loading configuration file with port and jwtSecret key
  final config = await loadConfig('config/config.json');

  ///Setting up auth middleware
  final auth = Authenticator(jwtSecret: config["secret"]);

  ///Init point of database
  ObjectBox.create();

  final apiService = ApiService(auth: auth);

  jigLogger.i("Server configuration: \n $config");

  final server = await serve(apiService.handler, "localhost", config["port"]);
  print('Server listening on port ${server.port}');
}
