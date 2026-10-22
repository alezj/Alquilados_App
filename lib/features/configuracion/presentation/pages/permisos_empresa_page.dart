import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';

class PermisosEmpresaPage extends ConsumerStatefulWidget {
  const PermisosEmpresaPage({super.key});

  @override
  ConsumerState<PermisosEmpresaPage> createState() =>
      _PermisosEmpresaPageState();
}

class _PermisosEmpresaPageState extends ConsumerState<PermisosEmpresaPage> {
  bool _loading = true;
  String? _error;
  String? _companyId;
  String? _roleId;
  bool _isPlatformAdmin = false;
  bool _canEdit = false;
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _permissions = [];
  Set<String> _assigned = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final userId = await ref.read(secureStorageProvider).getUserData();
      if (userId == null) throw Exception('No se encontró una sesión activa.');
      final admin = await api.post<dynamic>('/rpc/is_platform_admin');
      _isPlatformAdmin = admin.data == true;
      _canEdit = _isPlatformAdmin;
      if (_isPlatformAdmin) {
        final companyResponse = await api.get<dynamic>(
          '/companies?select=id,name,status&order=name',
        );
        _companies = companyResponse.data is List
            ? (companyResponse.data as List)
                  .whereType<Map<String, dynamic>>()
                  .map((company) => {...company, 'role': 'admin_empresa'})
                  .toList()
            : <Map<String, dynamic>>[];
      } else {
        final membershipResponse = await api.get<dynamic>(
          '/company_memberships?select=company_id,role,companies(name)&user_id=eq.$userId&status=eq.approved&order=requested_at.asc',
        );
        final memberships = membershipResponse.data is List
            ? (membershipResponse.data as List)
                  .whereType<Map<String, dynamic>>()
                  .toList()
            : <Map<String, dynamic>>[];
        if (memberships.isEmpty) {
          throw Exception('No tienes una membresía aprobada.');
        }
        _companies = memberships
            .map(
              (membership) => {
                'id': membership['company_id'],
                'name': (membership['companies'] as Map?)?['name'] ?? 'Empresa',
                'role': membership['role'],
              },
            )
            .toList();
      }
      _companyId ??= _companies.first['id'].toString();
      final membership = _companies.firstWhere(
        (company) => company['id'].toString() == _companyId,
      );
      _canEdit = _isPlatformAdmin || membership['role'] == 'admin_empresa';
      final rolesResponse = await api.get<dynamic>(
        '/roles?select=id,name&order=name',
      );
      _roles = rolesResponse.data is List
          ? (rolesResponse.data as List)
                .whereType<Map<String, dynamic>>()
                .toList()
          : <Map<String, dynamic>>[];
      _roleId ??= _roles.isEmpty ? null : _roles.first['id'].toString();
      final permissionResponse = await api.get<dynamic>(
        '/permissions?select=id,module,description&order=module,id',
      );
      _permissions = permissionResponse.data is List
          ? (permissionResponse.data as List)
                .whereType<Map<String, dynamic>>()
                .toList()
          : <Map<String, dynamic>>[];
      await _loadAssignments();
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAssignments() async {
    if (_companyId == null || _roleId == null) return;
    final response = await ref
        .read(apiClientProvider)
        .get<dynamic>(
          '/company_role_permissions?select=permission_id&company_id=eq.$_companyId&role_id=eq.$_roleId',
        );
    final rows = response.data is List
        ? (response.data as List).whereType<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
    _assigned = rows.map((row) => row['permission_id'].toString()).toSet();
  }

  Future<void> _setPermission(String permissionId, bool enabled) async {
    if (!_canEdit || _companyId == null || _roleId == null) return;
    try {
      final api = ref.read(apiClientProvider);
      if (enabled) {
        await api.post<void>(
          '/company_role_permissions',
          data: {
            'company_id': _companyId,
            'role_id': _roleId,
            'permission_id': permissionId,
          },
        );
      } else {
        await api.delete<void>(
          '/company_role_permissions?company_id=eq.$_companyId&role_id=eq.$_roleId&permission_id=eq.$permissionId',
        );
      }
      setState(() {
        if (enabled) {
          _assigned.add(permissionId);
        } else {
          _assigned.remove(permissionId);
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el permiso: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    final permissionsByModule = <String, List<Map<String, dynamic>>>{};
    for (final permission in _permissions) {
      permissionsByModule
          .putIfAbsent(permission['module'].toString(), () => [])
          .add(permission);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: _companyId,
          decoration: const InputDecoration(labelText: 'Empresa'),
          items: _companies
              .map(
                (company) => DropdownMenuItem(
                  value: company['id'].toString(),
                  child: Text(company['name'].toString()),
                ),
              )
              .toList(),
          onChanged: (value) async {
            if (value == null) return;
            final company = _companies.firstWhere(
              (item) => item['id'].toString() == value,
            );
            setState(() {
              _companyId = value;
              _canEdit = _isPlatformAdmin || company['role'] == 'admin_empresa';
            });
            await _loadAssignments();
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _roleId,
          decoration: const InputDecoration(labelText: 'Rol'),
          items: _roles
              .map(
                (role) => DropdownMenuItem(
                  value: role['id'].toString(),
                  child: Text(role['name'].toString()),
                ),
              )
              .toList(),
          onChanged: (value) async {
            if (value == null) return;
            setState(() => _roleId = value);
            await _loadAssignments();
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(height: 12),
        if (!_canEdit)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Puedes consultar los permisos. Solo un administrador de empresa puede modificarlos.',
              ),
            ),
          ),
        ...permissionsByModule.entries.map(
          (entry) => Card(
            child: ExpansionTile(
              title: Text(entry.key),
              children: entry.value.map((permission) {
                final permissionId = permission['id'].toString();
                return SwitchListTile(
                  value: _assigned.contains(permissionId),
                  onChanged: _canEdit
                      ? (value) => _setPermission(permissionId, value)
                      : null,
                  title: Text(permissionId),
                  subtitle: Text(permission['description']?.toString() ?? ''),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
