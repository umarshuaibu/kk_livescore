import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kklivescoreadmin/league_manager/firestore_service.dart';
import 'league_initialization_screen.dart';

class LeagueListScreen extends StatefulWidget {
  const LeagueListScreen({super.key});

  @override
  State<LeagueListScreen> createState() => _LeagueListScreenState();
}

class _LeagueListScreenState extends State<LeagueListScreen> {
  final _firestoreService = FirestoreService();
  List<dynamic> _leagues = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    final docs = await _firestoreService.fetchLeagues();
    setState(() {
      _leagues = docs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leagues'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _leagues.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final doc = _leagues[index];
                final data = (doc as dynamic).data() as Map<String, dynamic>;
                final title = data['name'] ?? 'Unnamed';
                return ListTile(
                  title: Text(title),
                  subtitle: Text(data['season'] ?? ''),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeagueInitializationScreen(leagueId: doc.id),
                      ),
                    );
                  },
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push("/create_league"),
        child: const Icon(Icons.add),
      ),

    );
  }
}