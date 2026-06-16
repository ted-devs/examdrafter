import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/question_draft.dart';
import '../services/draft_service.dart';

class ReviewPoolPage extends StatefulWidget {
  const ReviewPoolPage({super.key});

  @override
  State<ReviewPoolPage> createState() => _ReviewPoolPageState();
}

class _ReviewPoolPageState extends State<ReviewPoolPage> {
  final DraftService _draftService = DraftService();
  bool _isCommitteeLead = false;
  bool _showAll = false;
  bool _isWorking = false;

  Future<void> _castVote(String draftId, ReviewVote vote) async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      await _draftService.addReviewVote(
        draftId: draftId,
        voterId: FirebaseAuth.instance.currentUser?.uid ?? 'committee_member_1',
        vote: vote,
        isCommitteeLead: _isCommitteeLead,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record vote: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _manualDecision(String draftId, ReviewVote vote) async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      await _draftService.forceCommitteeDecision(
        draftId,
        vote,
        note: vote == ReviewVote.keep
            ? 'Approved during committee review.'
            : 'Rejected during committee review.',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not apply committee decision: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'in_review':
        return Colors.orange;
      case 'submitted':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _voteLabel(ReviewVote vote) {
    switch (vote) {
      case ReviewVote.keep:
        return 'Keep';
      case ReviewVote.drop:
        return 'Drop';
      case ReviewVote.abstain:
        return 'Abstain';
    }
  }

  @override
  Widget build(BuildContext context) {
    final drafts = _showAll
        ? _draftService.drafts
        : _draftService.submittedDrafts;
    final submittedCount = _draftService.submittedDrafts.length;
    final approvedCount = _draftService.questionBank.length;
    final votedCount = _draftService.totalVotes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Committee Review Pool'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Chip(
                label: Text('$submittedCount submitted'),
                backgroundColor: const Color(0xFFFDE68A),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: const Color(0xFF0F172A),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 900;

                    final left = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Committee review cockpit',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vote on submitted questions, resolve ties as a lead, and keep the review queue organized.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilterChip(
                              selected: _isCommitteeLead,
                              onSelected: (value) =>
                                  setState(() => _isCommitteeLead = value),
                              label: const Text('Committee Lead mode'),
                            ),
                            FilterChip(
                              selected: _showAll,
                              onSelected: (value) =>
                                  setState(() => _showAll = value),
                              label: const Text('Show all statuses'),
                            ),
                          ],
                        ),
                      ],
                    );

                    final right = Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _ReviewStat(
                          label: 'Submitted',
                          value: '$submittedCount',
                          color: const Color(0xFFF59E0B),
                        ),
                        _ReviewStat(
                          label: 'Approved bank',
                          value: '$approvedCount',
                          color: const Color(0xFF10B981),
                        ),
                        _ReviewStat(
                          label: 'Votes cast',
                          value: '$votedCount',
                          color: const Color(0xFF8B5CF6),
                        ),
                      ],
                    );

                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: left),
                          const SizedBox(width: 20),
                          right,
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [left, const SizedBox(height: 18), right],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (drafts.isEmpty)
              const _ReviewEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: drafts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final draft = drafts[index];
                  final votes = _draftService.reviewRecordsFor(draft.id!);
                  final keepVotes = votes
                      .where((vote) => vote.vote == ReviewVote.keep)
                      .length;
                  final dropVotes = votes
                      .where((vote) => vote.vote == ReviewVote.drop)
                      .length;
                  final abstainVotes = votes
                      .where((vote) => vote.vote == ReviewVote.abstain)
                      .length;
                  final tieBreaker = votes.any((vote) => vote.isTieBreaker);
                  final finalized = draft.status == 'approved' || draft.status == 'rejected';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  draft.questionText,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Chip(
                                label: Text(draft.status.toUpperCase()),
                                backgroundColor: _statusColor(
                                  draft.status,
                                ).withValues(alpha: 0.12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text('Difficulty: ${draft.difficulty}'),
                              ),
                              Chip(
                                label: Text(
                                  draft.topics.isEmpty
                                      ? 'No topics tagged'
                                      : draft.topics.join(', '),
                                ),
                              ),
                              if (tieBreaker)
                                const Chip(label: Text('Tie-breaker used')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Options',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          ...draft.options.map(
                            (option) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    option.isCorrect
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    size: 18,
                                    color: option.isCorrect
                                        ? const Color(0xFF10B981)
                                        : Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(option.text)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              Chip(label: Text('Keep: $keepVotes')),
                              Chip(label: Text('Drop: $dropVotes')),
                              Chip(label: Text('Abstain: $abstainVotes')),
                            ],
                          ),
                          if (draft.committeeNote != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                draft.committeeNote!,
                                style: TextStyle(
                                  color: Colors.blueGrey.shade700,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: finalized || _isWorking
                                    ? null
                                    : () => _castVote(draft.id!, ReviewVote.keep),
                                icon: const Icon(Icons.thumb_up_alt_rounded),
                                label: Text(_voteLabel(ReviewVote.keep)),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: finalized || _isWorking
                                    ? null
                                    : () => _castVote(draft.id!, ReviewVote.drop),
                                icon: const Icon(Icons.thumb_down_alt_rounded),
                                label: Text(_voteLabel(ReviewVote.drop)),
                              ),
                              OutlinedButton.icon(
                                onPressed: finalized || _isWorking
                                    ? null
                                    : () => _castVote(draft.id!, ReviewVote.abstain),
                                icon: const Icon(Icons.remove_circle_outline),
                                label: Text(_voteLabel(ReviewVote.abstain)),
                              ),
                              TextButton.icon(
                                onPressed: finalized || _isWorking
                                    ? null
                                    : () => _manualDecision(draft.id!, ReviewVote.keep),
                                icon: const Icon(Icons.gavel_rounded),
                                label: const Text('Force approve'),
                              ),
                              TextButton.icon(
                                onPressed: finalized || _isWorking
                                    ? null
                                    : () => _manualDecision(draft.id!, ReviewVote.drop),
                                icon: const Icon(Icons.gavel_outlined),
                                label: const Text('Force reject'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewStat extends StatelessWidget {
  const _ReviewStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.circle, color: color, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewEmptyState extends StatelessWidget {
  const _ReviewEmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFDE68A),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.inbox_rounded, color: Color(0xFF92400E)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No drafts in the queue',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submitted questions will appear here for committee voting. Turn on “Show all statuses” to inspect approved or rejected items.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
