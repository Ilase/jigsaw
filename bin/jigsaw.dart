import 'package:jigsaw/data/db/db_service.dart';
import 'package:jigsaw/data/j_logger.dart';
import 'package:jigsaw/domain/api/api_service.dart';
import 'package:jigsaw/domain/api/config.dart';
import 'package:jigsaw/domain/api/jwt/jwt_auth.dart';
import 'package:shelf/shelf_io.dart';

void main(List<String> args) async {
  ///Loading configuration file with port and jwtSecret key
  final config = await loadConfig('config/config.json');

  ///Init point of database
  ObjectBox.create();

  ///Setting up auth middleware
  final auth = Authenticator(
    jwtSecret: config['secret'],
    usersBox: ObjectBox.instance.usersBox,
    rolesBox: ObjectBox.instance.rolesBox, // Теперь передаём сюда
  );
  final apiService = ApiService(auth: auth);

  jigLogger.i("Server configuration: \n $config");

  final server = await serve(apiService.handler, "localhost", config["port"]);
  print('Server listening on port ${server.port}');
}
