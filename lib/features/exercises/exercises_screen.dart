import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/api/admin_providers.dart';
import '../../core/api/admin_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/utils/exercise_media.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/admin_app_bar.dart';
import '../../widgets/app_modal_sheet.dart';
import '../../widgets/common.dart';
import '../../widgets/hold_button.dart';
import '../../widgets/list_cards.dart';
import '../../widgets/media_viewer.dart';
import '../../widgets/rubber_segment.dart';
import '../meal_library/meal_library_view.dart';
import 'exercise_edit_sheet.dart';

const _sectionExercises = 'exercises';
const _sectionHyrox = 'hyrox';
const _sectionMeals = 'meals';

class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  Timer? _debounce;
  String _q = '';
  String _section = _sectionExercises;
  bool _mealsOpened = false;

  bool get _onMeals => _section == _sectionMeals;
  bool get _onHyrox => _section == _sectionHyrox;

  ExerciseLibraryQuery get _exerciseQuery => ExerciseLibraryQuery(
        q: _q,
        library: _onHyrox ? 'hyrox' : 'workout',
      );

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _q = value.trim());
    });
  }

  Future<void> _edit([Exercise? existing]) async {
    final body = await showExerciseEditSheet(
      context,
      ref: ref,
      existing: existing,
    );
    if (body == null || !mounted) return;
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (existing == null) {
        await repo.createExercise({
          ...body,
          'library': _onHyrox ? 'hyrox' : 'workout',
        });
      } else {
        await repo.updateExercise(
          existing.uuid.isNotEmpty ? existing.uuid : existing.id,
          body,
        );
      }
      await ref.refresh(exercisesProvider(_exerciseQuery).future);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(Exercise e) async {
    final ok = await showHoldToDeleteSheet(
      context,
      title: 'Delete exercise?',
      message: e.name,
    );
    if (!ok) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .deleteExercise(e.uuid.isNotEmpty ? e.uuid : e.id);
      await ref.refresh(exercisesProvider(_exerciseQuery).future);
    } on ApiException catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(exercisesProvider(_exerciseQuery));
    final items = async.asData?.value ?? const <Exercise>[];
    final showBlocking = async.isLoading && async.asData?.value == null;
    final sheetOpen = ref.watch(shellSheetDepthProvider) > 0;

    return Scaffold(
      appBar: AdminAppBar(
        title: 'Library',
        searchController: _search,
        searchHint: _onMeals
            ? 'Search meals'
            : _onHyrox
                ? 'Search Hyrox exercises'
                : 'Search exercises',
        onSearchChanged: _onSearchChanged,
        extraActions: [
          if (!_onMeals && async.isLoading && async.asData?.value != null)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: sheetOpen
          ? null
          : FloatingActionButton(
              heroTag: 'exercises_add_fab',
              tooltip: _onMeals
                  ? 'Add meal'
                  : _onHyrox
                      ? 'Add Hyrox exercise'
                      : 'Add exercise',
              onPressed: AppHaptics.wrap(
                () => _onMeals ? editLibraryMeal(context, ref) : _edit(),
              ),
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: RubberSegment(
              items: const [
                RubberSegmentItem(value: _sectionExercises, label: 'Exercises'),
                RubberSegmentItem(value: _sectionHyrox, label: 'Hyrox'),
                RubberSegmentItem(value: _sectionMeals, label: 'Meals'),
              ],
              value: _section,
              onChanged: (v) => setState(() {
                _section = v;
                if (v == _sectionMeals) _mealsOpened = true;
              }),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _onMeals ? 2 : (_onHyrox ? 1 : 0),
              children: [
                _exerciseList(async, _onHyrox ? const [] : items, showBlocking && !_onHyrox),
                _exerciseList(async, _onHyrox ? items : const [], showBlocking && _onHyrox),
                if (_mealsOpened)
                  MealLibraryView(query: _q)
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exerciseList(
    AsyncValue<List<Exercise>> async,
    List<Exercise> items,
    bool showBlocking,
  ) {
    return AsyncBody(
        loading: showBlocking,
        error: async.hasError && async.asData?.value == null
            ? async.error.toString()
            : null,
        onRetry: () => ref.refresh(exercisesProvider(_exerciseQuery).future),
        empty: !showBlocking && items.isEmpty,
        emptyLabel: _onHyrox ? 'No Hyrox exercises' : 'No exercises',
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(exercisesProvider(_exerciseQuery).future),
          child: ListView.separated(
            padding: PageInsets.page,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: PageInsets.cardGap),
            itemBuilder: (_, i) {
              final e = items[i];
              return LibrarySwipeCard(
                showHint: i == 0,
                onEdit: () => _edit(e),
                onDelete: () => _delete(e),
                child: AdminListCard(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MediaThumb(
                        imageUrl: e.imageUrl,
                        size: 72,
                        icon: Iconsax.weight,
                        label: 'Image',
                        onTap: hasExerciseImage(e.imageUrl)
                            ? () => showExerciseImageViewer(
                                  context,
                                  imageUrl: e.imageUrl!.trim(),
                                  title: e.name,
                                )
                            : () {
                                AppHaptics.selection();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No image for this exercise'),
                                  ),
                                );
                              },
                      ),
                      const SizedBox(width: 10),
                      VideoThumb(
                        videoUrl: e.videoUrl,
                        width: 56,
                        height: 72,
                        onTap: hasExerciseVideo(e.videoUrl)
                            ? () => showExerciseVideoViewer(
                                  context,
                                  videoUrl: e.videoUrl!.trim(),
                                  title: e.name,
                                )
                            : () {
                                AppHaptics.selection();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No video for this exercise'),
                                  ),
                                );
                              },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CardTitle(e.name),
                            const SizedBox(height: 6),
                            MetaText(
                              [
                                if (e.muscleGroup.isNotEmpty) e.muscleGroup,
                                if (e.equipment.isNotEmpty) e.equipment,
                              ].join(' · '),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (e.difficulty.isNotEmpty)
                                  StatusPill(label: e.difficulty),
                                if (e.target.isNotEmpty)
                                  StatusPill(
                                    label: e.target,
                                    tone: StatusPillTone.success,
                                  ),
                                if ((e.videoUrl ?? '').trim().isNotEmpty)
                                  const StatusPill(
                                    label: 'Has video',
                                    tone: StatusPillTone.success,
                                  )
                                else
                                  const StatusPill(label: 'No video'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              );
            },
          ),
        ),
    );
  }
}
