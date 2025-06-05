import 'package:jigsaw/data/db/db_service.dart';
import 'package:jigsaw/data/j_logger.dart';
import 'package:jigsaw/domain/api/api_service.dart';
import 'package:jigsaw/domain/api/config.dart';
import 'package:jigsaw/domain/api/jwt/jwt_auth.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

void main(List<String> args) async {
  ///Loading configuration file with port and jwtSecret key
  final config = await loadConfig('config/config.json');

  ///Init point of database
  ObjectBox.create();

  ///Setting up auth middleware
  final auth = Authenticator(
    jwtSecret: config['secret'],
    usersBox: ObjectBox.instance.usersBox,
    rolesBox: ObjectBox.instance.rolesBox,
    tasksBox: ObjectBox.instance.taskBox,
    projectsBox: ObjectBox.instance.projectsBox,
  );
  final apiService = ApiService(auth: auth);
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(
        auth.verifyJWT(
          excludedPaths: ['api/v1/login', 'api/v1/refresh', 'api/v1/check'],
        ),
      )
      // .addHandler(Router()..mount('/api/v1', apiService.router));
      .addHandler((Router()..mount('/api/v1', apiService.router.call)).call);

  jigLogger.i("Server configuration: \n $config");

  final server = await serve(handler, "localhost", config["port"]);
  print('Server listening on port ${server.port}');
}
