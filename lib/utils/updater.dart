import "dart:io";
import "dart:async";

import "package:collection/collection.dart";
import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:open_file/open_file.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:path_provider/path_provider.dart";
import "package:url_launcher/url_launcher.dart";
import "package:version/version.dart";
import "package:permission_handler/permission_handler.dart";

Future<void> checkForUpdates(final BuildContext context) async {
  final PackageInfo packageInfo = await PackageInfo.fromPlatform();
  final response = await Dio().get(
    "https://api.github.com/repos/Unofficial-Filman-Client/unofficial-filman-client-tv/releases/latest",
  );

  final Version currentVersion = Version.parse(packageInfo.version);

  final Version latestVersion = Version.parse(response.data["tag_name"]);

  if (currentVersion < latestVersion) {
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (final context) {
          return AlertDialog(
            title: const Text("Dostępna jest nowa wersja aplikacji"),
            content: Text(
              "Twoja wersja: ${currentVersion.toString()}\nNajnowsza wersja: ${latestVersion.toString()}",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Może później"),
              ),
              Platform.isAndroid
                  ? TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        downloadAndInstallApk(context, response, (final e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                dismissDirection: DismissDirection.horizontal,
                                behavior: SnackBarBehavior.floating,
                                showCloseIcon: true,
                              ),
                            );
                          }
                        });
                      },
                      child: const Text("Aktualizuj"),
                    )
                  : TextButton(
                      onPressed: () async {
                        final url = Uri.parse(
                          "https://github.com/Unofficial-Filman-Client/unofficial-filman-client-tv/releases/latest",
                        );
                        if (!await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        )) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "Nie można otworzyć linku w przeglądarce"),
                                dismissDirection: DismissDirection.horizontal,
                                behavior: SnackBarBehavior.floating,
                                showCloseIcon: true,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text("Przejdź do wydania"),
                    ),
            ],
          );
        },
      );
    }
  }
}

Future<void> downloadAndInstallApk(
  final BuildContext context,
  final Response<dynamic> response,
  final Function(Exception) onError,
) async {
  await Permission.requestInstallPackages.request();
  final permissionStatus = await Permission.requestInstallPackages.status;

  if (permissionStatus.isDenied || permissionStatus.isRestricted) {
    onError(Exception("Brak uprawnień do instalacji aplikacji"));
    return;
  }

  if (permissionStatus.isGranted) {
    final assets = response.data["assets"];
    if (assets is List) {
      final apkAsset = assets.firstWhereOrNull(
        (final asset) => asset["name"] == "unofficial-filman-tv.apk",
      );

      if (apkAsset != null && apkAsset["browser_download_url"] is String) {
        final tempDir = await getTemporaryDirectory();
        final savePath = '${tempDir.path}/${response.data["tag_name"]}.apk';

        if (!context.mounted) return;
        if (File(savePath).existsSync()) {
          _showExistingFileDialog(context, apkAsset, savePath);
        } else {
          _downloadAndDisplayProgress(context, apkAsset, savePath);
        }
      } else {
        onError(Exception("Brak linku do pobrania pliku"));
      }
    } else {
      onError(Exception("Brak wydań dla tej wersji aplikacji"));
    }
  }
}

void _showExistingFileDialog(
  final BuildContext context,
  final dynamic version,
  final String savePath,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (final context) {
      return AlertDialog(
        title: const Text("Pobierana wersja już istnieje"),
        content: const Text("Plik instalacyjny został już wcześniej pobrany"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadAndDisplayProgress(context, version, savePath);
            },
            child: const Text("Pobierz ponownie"),
          ),
          TextButton(
            onPressed: () => OpenFile.open(savePath),
            child: const Text("Instaluj"),
          ),
        ],
      );
    },
  );
}

void _downloadAndDisplayProgress(
    final BuildContext context, final dynamic version, final String savePath) {
  final downloadProgress = StreamController<double>();

  Dio().download(
    version["browser_download_url"],
    savePath,
    onReceiveProgress: (final received, final total) {
      if (total > 0) {
        downloadProgress.add(received / total);
      }
    },
    deleteOnError: true,
  ).then((final _) async {
    await OpenFile.open(savePath);
  });

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (final context) {
      return AlertDialog(
        title: const Text("Pobieranie pliku"),
        content: StreamBuilder<double>(
          stream: downloadProgress.stream,
          builder: (final context, final snapshot) {
            final progress = snapshot.data ?? 0.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: LinearProgressIndicator(value: progress),
                ),
                const SizedBox(width: 8),
                Text("${(progress * 100).toStringAsFixed(0)}%"),
              ],
            );
          },
        ),
      );
    },
  );
}
