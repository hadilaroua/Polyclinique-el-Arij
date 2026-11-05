String getBriefingSummaryPreview(Map<String, dynamic> briefing, {required String fallback}) {
  final summary = (briefing['aiSummaryPreview'] ?? briefing['aiSummary'] ?? briefing['summary'])
      ?.toString()
      .trim();
  return summary == null || summary.isEmpty ? fallback : summary;
}
