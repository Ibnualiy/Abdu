import '../services/team_service.dart';

/// What each role can reach in the UI. This is NOT the security
/// boundary — every member can still technically read/write any of
/// their organization's data via the API, because migration_phase7_
/// roles.sql's RLS checks org membership, not role. This class only
/// controls what's shown, so a Sales staff member's phone doesn't get
/// cluttered with (or accidentally trip over) purchase costs, other
/// staff's team management, etc. Enforcing role at the database level
/// too is a reasonable next step if you need it — same shape, just
/// added to the SQL policies instead of checked here.
class Permissions {
  final TeamRole role;
  const Permissions(this.role);

  bool get canRecordSales =>
      role == TeamRole.owner || role == TeamRole.sales;

  bool get canViewProfitAnalysis =>
      role == TeamRole.owner || role == TeamRole.accountant;

  bool get canManageProducts =>
      role == TeamRole.owner || role == TeamRole.warehouse;

  bool get canManageCustomers => role != TeamRole.warehouse;

  bool get canManagePurchaseOrders =>
      role == TeamRole.owner || role == TeamRole.warehouse;

  bool get canViewPurchaseOrders => role != TeamRole.sales;

  bool get canManageTeam => role == TeamRole.owner;

  bool get canManageBranches => role == TeamRole.owner;

  String roleLabel() {
    switch (role) {
      case TeamRole.owner:
        return 'ባለቤት (Owner)';
      case TeamRole.sales:
        return 'ሽያጭ (Sales)';
      case TeamRole.warehouse:
        return 'መጋዘን (Warehouse)';
      case TeamRole.accountant:
        return 'አካውንታንት (Accountant)';
    }
  }
}
