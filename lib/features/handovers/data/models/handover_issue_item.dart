class HandoverIssueItem {
  const HandoverIssueItem({
    required this.id,
    required this.handoverIssueId,
    required this.equipmentId,
    required this.issueType,
    this.description,
    this.status,
  });
  final String id, handoverIssueId, equipmentId, issueType;
  final String? description, status;
  factory HandoverIssueItem.fromJson(Map<String, dynamic> j) =>
      HandoverIssueItem(
        id: j['id'] as String,
        handoverIssueId: j['handoverIssueId'] as String,
        equipmentId: j['equipmentId'] as String,
        issueType: j['issueType'] as String,
        description: j['description'] as String?,
        status: j['status'] as String?,
      );
}
