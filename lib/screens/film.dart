import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:fast_cached_network_image/fast_cached_network_image.dart";
import "package:unofficial_filman_client/notifiers/filman.dart";
import "package:unofficial_filman_client/notifiers/watched.dart";
import "package:unofficial_filman_client/notifiers/download.dart";
import "package:unofficial_filman_client/notifiers/settings.dart";
import "package:unofficial_filman_client/screens/player.dart";
import "package:unofficial_filman_client/types/film_details.dart";
import "package:unofficial_filman_client/utils/title.dart";
import "package:unofficial_filman_client/utils/select_dialog.dart";
import "package:unofficial_filman_client/widgets/error_handling.dart";
import "package:unofficial_filman_client/widgets/episodes.dart";
import "package:unofficial_filman_client/widgets/focus_inkwell.dart";

class FilmScreen extends StatefulWidget {
  final String url;
  final String title;
  final String image;
  final FilmDetails? filmDetails;

  const FilmScreen({
    super.key,
    required this.url,
    required this.title,
    required this.image,
    this.filmDetails,
  });

  FilmScreen.fromDetails({
    super.key,
    required final FilmDetails details,
  })  : url = details.url,
        title = details.title,
        image = details.imageUrl,
        filmDetails = details;

  @override
  State<FilmScreen> createState() => _FilmScreenState();
}

class _FilmScreenState extends State<FilmScreen> {
  late Future<FilmDetails> lazyFilm;

  @override
  void initState() {
    super.initState();
    lazyFilm = widget.filmDetails != null
        ? Future.value(widget.filmDetails)
        : context.read<FilmanNotifier>().getFilmDetails(widget.url);
  }

  Widget _buildActionButton(
      final IconData icon, final String label, final bool hasFocus) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: hasFocus ? colorScheme.secondaryContainer : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFocus
              ? colorScheme.secondary
              : colorScheme.outline.withOpacity(0.12),
          width: hasFocus ? 2 : 1,
        ),
        boxShadow: hasFocus
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: hasFocus
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: hasFocus
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePlayButton(final FilmDetails film) async {
    if (film.isSerial) {
      if (film.seasons?.isNotEmpty == true) {
        _showEpisodesDialog(film);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Brak dostępnych sezonów"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final watched = context
        .read<WatchedNotifier>()
        .films
        .firstWhereOrNull((final e) => e.filmDetails.url == film.url);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (final context) => watched != null
            ? FilmanPlayer.fromDetails(
                filmDetails: film,
                startFrom: watched.watchedInSec,
                savedDuration: watched.totalInSec,
              )
            : FilmanPlayer.fromDetails(filmDetails: film),
      ),
    );
  }

  void _handleDownload(final FilmDetails film) async {
    final downloadNotifier = context.read<DownloadNotifier>();
    final downloaded = downloadNotifier.downloadedSerials
        .firstWhereOrNull((final s) => s.serial.url == film.url);

    if (downloaded != null || film.links == null || film.links!.isEmpty) {
      return;
    }

    final (link, quality) = await getUserSelectedPreferences(film.links!);
    if (link == null || quality == null) {
      return;
    }

    downloadNotifier.addFilmToDownload(
      film,
      link,
      quality,
      context.read<SettingsNotifier>(),
      null,
    );
  }

  void _showEpisodesDialog(final FilmDetails filmDetails) {
    showDialog(
      context: context,
      builder: (final context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: EpisodesModal(filmDetails: filmDetails),
        ),
      ),
    );
  }

  Widget _buildDownloadButton(final FilmDetails film, final bool hasFocus) {
    if (film.isSerial) return const SizedBox();

    final downloadNotifier = context.watch<DownloadNotifier>();
    final downloaded = downloadNotifier.downloadedSerials
        .firstWhereOrNull((final s) => s.serial.url == film.url);
    final isDownloading = downloadNotifier.downloading
        .any((final element) => element.film.url == film.url);

    final icon = isDownloading
        ? Icons.downloading
        : (downloaded != null ? Icons.save : Icons.download);
    final label = isDownloading
        ? "Pobieranie..."
        : (downloaded != null ? "Zapisane" : "Pobierz");

    return _buildActionButton(icon, label, hasFocus);
  }

  Widget _buildContent(final FilmDetails film) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FastCachedImage(
                    url: widget.image,
                    width: MediaQuery.of(context).size.width * 0.3,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DisplayTitle(
                        title: widget.title,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        film.categories.join(" ").toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          Chip(
                            label: Text(
                              film.releaseDate,
                              style: const TextStyle(fontSize: 16),
                            ),
                            avatar: const Icon(Icons.calendar_today),
                          ),
                          Chip(
                            label: Text(
                              film.viewCount,
                              style: const TextStyle(fontSize: 16),
                            ),
                            avatar: const Icon(Icons.visibility),
                          ),
                          Chip(
                            label: Text(
                              film.country,
                              style: const TextStyle(fontSize: 16),
                            ),
                            avatar: const Icon(Icons.flag),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        film.desc,
                        maxLines: 7,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          FocusInkWell(
                            onTap: () => Navigator.of(context).pop(),
                            builder: (final hasFocus) => _buildActionButton(
                              Icons.arrow_back,
                              "Powrót",
                              hasFocus,
                            ),
                          ),
                          const SizedBox(width: 16),
                          FocusInkWell(
                            onTap: () => _handlePlayButton(film),
                            autofocus: true,
                            builder: (final hasFocus) => _buildActionButton(
                              film.isSerial ? Icons.list : Icons.play_arrow,
                              film.isSerial ? "Odcinki" : "Odtwórz",
                              hasFocus,
                            ),
                          ),
                          if (!film.isSerial) ...[
                            const SizedBox(width: 16),
                            FocusInkWell(
                              onTap: () => _handleDownload(film),
                              builder: (final hasFocus) =>
                                  _buildDownloadButton(film, hasFocus),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Consumer<WatchedNotifier>(
              builder: (final context, final watchedNotifier, final _) {
                final watched = watchedNotifier.films.firstWhereOrNull(
                    (final e) => e.filmDetails.url == widget.url);
                return watched != null
                    ? LinearProgressIndicator(value: watched.watchedPercentage)
                    : const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      body: FutureBuilder<FilmDetails>(
        future: lazyFilm,
        builder: (final context, final snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorHandling(
              error: snapshot.error!,
              onLogin: (final response) =>
                  Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (final context) => FilmScreen(
                    url: widget.url,
                    title: widget.title,
                    image: widget.image,
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("Brak danych"));
          }
          return _buildContent(snapshot.data!);
        },
      ),
    );
  }
}
