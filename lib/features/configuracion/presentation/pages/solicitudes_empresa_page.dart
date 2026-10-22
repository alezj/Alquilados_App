import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/shared/widgets/app_button.dart';

class SolicitudesEmpresaPage extends ConsumerStatefulWidget {
  const SolicitudesEmpresaPage({super.key});

  @override
  ConsumerState<SolicitudesEmpresaPage> createState() =>
      _SolicitudesEmpresaPageState();
}

class _SolicitudesEmpresaPageState
    extends ConsumerState<SolicitudesEmpresaPage> {
  late Future<List<Map<String, dynamic>>> _requests;
  late Future<List<Map<String, dynamic>>> _companies;
  bool _isPlatformAdmin = false;
  final Map<String, String> _selectedAppRoles = {};
  final Map<String, String> _selectedMembershipRoles = {};

  @override
  void initState() {
    super.initState();
    _requests = _load();
    _companies = _loadCompanies();
  }

  Future<List<Map<String, dynamic>>> _loadCompanies() async {
    final api = ref.read(apiClientProvider);
    final isAdmin = await api.post<dynamic>('/rpc/is_platform_admin');
    if (isAdmin.data != true) return const [];
    final response = await api.get<dynamic>(
      '/companies?select=id,name,slug,status&order=name',
    );
    return response.data is List
        ? (response.data as List).whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  Future<void> _createCompany() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva empresa'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.isEmpty) return;
    final normalizedSlug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final slug = normalizedSlug.isEmpty
        ? 'empresa-${DateTime.now().millisecondsSinceEpoch}'
        : normalizedSlug;
    try {
      await ref
          .read(apiClientProvider)
          .post<void>(
            '/companies',
            data: {'name': name, 'slug': slug, 'status': 'active'},
          );
      if (!mounted) return;
      setState(() => _companies = _loadCompanies());
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Empresa creada.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo crear la empresa: $error')),
        );
    }
  }

  Future<void> _toggleCompany(Map<String, dynamic> company) async {
    final nextStatus = company['status'] == 'active' ? 'suspended' : 'active';
    try {
      await ref
          .read(apiClientProvider)
          .patch<void>(
            '/companies?id=eq.${company['id']}',
            data: {
              'status': nextStatus,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          );
      if (mounted) setState(() => _companies = _loadCompanies());
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar la empresa: $error')),
        );
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final api = ref.read(apiClientProvider);
    final adminResponse = await api.post<dynamic>('/rpc/is_platform_admin');
    _isPlatformAdmin = adminResponse.data == true;
    final response = await api.get<dynamic>(
      '/company_memberships?select=id,user_id,company_id,role,requested_at&status=eq.pending&order=requested_at.asc',
    );
    final memberships = response.data is List
        ? (response.data as List).whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    if (memberships.isEmpty) return memberships;
    final userIds = memberships
        .map((row) => row['user_id'].toString())
        .toSet()
        .join(',');
    final usersResponse = await api.get<dynamic>(
      '/profiles?select=id,full_name,email&id=in.($userIds)',
    );
    final users = usersResponse.data is List
        ? (usersResponse.data as List)
              .whereType<Map<String, dynamic>>()
              .toList()
        : <Map<String, dynamic>>[];
    final byId = {for (final user in users) user['id'].toString(): user};
    return memberships
        .map((row) => {...row, 'profile': byId[row['user_id'].toString()]})
        .toList();
  }

  Future<void> _review(
    Map<String, dynamic> request, {
    required bool approve,
  }) async {
    try {
      await ref
          .read(apiClientProvider)
          .post<void>(
            '/rpc/review_company_membership',
            data: {
              'membership_id': request['id'],
              'approve': approve,
              'assigned_role':
                  _selectedMembershipRoles[request['id'].toString()] ??
                  'usuario',
              'assigned_app_role':
                  _selectedAppRoles[request['id'].toString()] ?? 'agente',
            },
          );
      if (!mounted) return;
      setState(() => _requests = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Solicitud aprobada.' : 'Solicitud rechazada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo procesar la solicitud: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de acceso')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No tienes permiso para revisar solicitudes o no se pudo cargar la información.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          final requests = snapshot.data ?? const [];
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _companies,
            builder: (context, companySnapshot) {
              final companies = companySnapshot.data ?? const [];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isPlatformAdmin) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Empresas',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          onPressed: _createCompany,
                          icon: const Icon(Icons.add_business_outlined),
                          tooltip: 'Crear empresa',
                        ),
                      ],
                    ),
                    if (companySnapshot.hasError)
                      Text(
                        'No se pudieron cargar las empresas: ${companySnapshot.error}',
                      )
                    else
                      ...companies.map(
                        (company) => Card(
                          child: ListTile(
                            title: Text(company['name'].toString()),
                            subtitle: Text(
                              '${company['slug']} · ${company['status']}',
                            ),
                            trailing: TextButton(
                              onPressed: () => _toggleCompany(company),
                              child: Text(
                                company['status'] == 'active'
                                    ? 'Suspender'
                                    : 'Activar',
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Solicitudes pendientes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (requests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No hay solicitudes pendientes.'),
                      ),
                    ),
                  ...requests.map((request) {
                    final profile =
                        request['profile'] as Map<String, dynamic>? ?? const {};
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile['full_name']?.toString().isNotEmpty ==
                                      true
                                  ? profile['full_name'].toString()
                                  : 'Usuario',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(profile['email']?.toString() ?? ''),
                            const SizedBox(height: 12),
                            Text('Rol solicitado: usuario'),
                            DropdownButtonFormField<String>(
                              value:
                                  _selectedAppRoles[request['id'].toString()] ??
                                  'agente',
                              decoration: const InputDecoration(
                                labelText: 'Rol y permisos',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 'agente',
                                  child: Text('Agente'),
                                ),
                                const DropdownMenuItem(
                                  value: 'cliente',
                                  child: Text('Cliente'),
                                ),
                                const DropdownMenuItem(
                                  value: 'mantenimiento',
                                  child: Text('Mantenimiento'),
                                ),
                                if (_isPlatformAdmin)
                                  const DropdownMenuItem(
                                    value: 'admin',
                                    child: Text('Administrador CRM'),
                                  ),
                              ],
                              onChanged: (value) => setState(() {
                                if (value != null) {
                                  _selectedAppRoles[request['id'].toString()] =
                                      value;
                                }
                              }),
                            ),
                            if (_isPlatformAdmin) ...[
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value:
                                    _selectedMembershipRoles[request['id']
                                        .toString()] ??
                                    'usuario',
                                decoration: const InputDecoration(
                                  labelText: 'Acceso a la empresa',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'usuario',
                                    child: Text('Usuario'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'admin_empresa',
                                    child: Text('Administrador de empresa'),
                                  ),
                                ],
                                onChanged: (value) => setState(() {
                                  if (value != null) {
                                    _selectedMembershipRoles[request['id']
                                            .toString()] =
                                        value;
                                  }
                                }),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    text: 'Rechazar',
                                    variant: AppButtonVariant.outline,
                                    isDense: true,
                                    onPressed: () =>
                                        _review(request, approve: false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: AppButton(
                                    text: 'Aprobar',
                                    isDense: true,
                                    onPressed: () =>
                                        _review(request, approve: true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
