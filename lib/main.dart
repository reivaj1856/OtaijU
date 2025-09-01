import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// NOTE: Si usas FlutterFire CLI para generar firebase_options.dart, impórtalo aquí
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const OtaijuApp());
}

String makeConversationId(String a, String b) {
  return a.hashCode <= b.hashCode ? '${a}_${b}' : '${b}_${a}';
}

class OtaijuApp extends StatelessWidget {
  const OtaijuApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Paleta derivada del logo (naranja -- teal)
    const orange = Color(0xFFFF7A18);
    const darkOrange = Color(0xFFFF4E00);
    const teal = Color(0xFF00B7B3);

    return MultiProvider(
      providers: [
        StreamProvider<User?>.value(
          value: FirebaseAuth.instance.authStateChanges(),
          initialData: FirebaseAuth.instance.currentUser,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'OtaijU',
        theme: ThemeData(
          primaryColor: orange,
          colorScheme: ColorScheme.fromSeed(seedColor: orange),
          appBarTheme: const AppBarTheme(
            backgroundColor: darkOrange,
            foregroundColor: Colors.white,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            elevation: 6,
          ),
          useMaterial3: true,
        ),
        home: const Root(),
      ),
    );
  }
}

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    if (user == null) return const AuthFlow();
    return HomeScreen(uid: user.uid);
  }
}

// ------------------ AuthFlow: Login / Signup ------------------
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('lib/assets/logo.png', width: 140, height: 140),
                const SizedBox(height: 12),
                Text('OtaijU', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: isLogin ? LoginForm(onSwitch: () { setState(() => isLogin = false); }) : SignupForm(onSwitch: () { setState(() => isLogin = true); }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  final VoidCallback onSwitch;
  const LoginForm({required this.onSwitch, super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> _submit() async {
    setState(() { loading = true; error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      print('Error de Firebase Auth (Login): ${e.code} - ${e.message}');
      setState(() { error = e.message; });
    } catch (e) {
      print('Ocurrió un error inesperado (Login): $e');
      setState(() { error = 'Un error inesperado ocurrió. Por favor, inténtalo de nuevo.'; });
    } finally {
      setState(() { loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo electrónico')),
        TextField(controller: _password, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
        const SizedBox(height: 12),
        if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: loading ? null : _submit, child: loading ? const CircularProgressIndicator() : const Text('Iniciar sesión')),
        TextButton(onPressed: widget.onSwitch, child: const Text('¿No tienes cuenta? Crear cuenta')),
      ],
    );
  }
}

class SignupForm extends StatefulWidget {
  final VoidCallback onSwitch;
  const SignupForm({required this.onSwitch, super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  bool loading = false;
  String? error;

  Future<bool> _isUniqueUsername(String username) async {
    final snap = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: username).get();
    return snap.docs.isEmpty;
  }

  Future<bool> _isUniqueEmail(String email) async {
    final snap = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).get();
    return snap.docs.isEmpty;
  }

  Future<void> _submit() async {
    setState(() { loading = true; error = null; });
    final username = _username.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (!await _isUniqueUsername(username)) {
      setState(() { error = 'El nombre de usuario ya existe'; loading = false; });
      return;
    }

    if (!await _isUniqueEmail(email)) {
      setState(() { error = 'El correo ya está registrado'; loading = false; });
      return;
    }

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'username': username,
        'email': email,
        'bio': '',
        'following': [],
        'followers': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      print('Error de Firebase Auth (Signup): ${e.code} - ${e.message}');
      setState(() { error = e.message; });
    } catch (e) {
      print('Ocurrió un error inesperado (Signup): $e');
      setState(() { error = 'Un error inesperado ocurrió. Por favor, inténtalo de nuevo.'; });
    } finally {
      setState(() { loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(controller: _username, decoration: const InputDecoration(labelText: 'Nombre de usuario')),
        TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo electrónico')),
        TextField(controller: _password, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
        const SizedBox(height: 12),
        if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: loading ? null : _submit, child: loading ? const CircularProgressIndicator() : const Text('Crear cuenta')),
        TextButton(onPressed: widget.onSwitch, child: const Text('¿Ya tienes cuenta? Iniciar sesión')),
      ],
    );
  }
}

// ------------------ HomeScreen con Bottom Navigation: Publicaciones, Grupos, Mensajes y Perfil ------------------
class HomeScreen extends StatefulWidget {
  final String uid;
  const HomeScreen({required this.uid, super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selected = 0;

  @override
  void initState() {
    super.initState();
    _listenForFollows(); // Start listening for follow events
  }

  void _listenForFollows() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Listen for when the current user starts following someone
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .listen((snapshot) {
      snapshot.docChanges.forEach((change) {
        if (change.type == DocumentChangeType.added) {
          final followedUserId = change.doc.id;
          _createOrGetChat(uid, followedUserId);
        }
      });
    });

    // Listen for when someone starts following the current user
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('followers')
        .snapshots()
        .listen((snapshot) {
      snapshot.docChanges.forEach((change) {
        if (change.type == DocumentChangeType.added) {
          final followerUserId = change.doc.id;
          _createOrGetChat(uid, followerUserId);
        }
      });
    });
  }

  Future<void> _createOrGetChat(String userId1, String userId2) async {
    // Determine the conversation ID (consistent order)
    final convoId = makeConversationId(userId1, userId2); // Using global makeConversationId

    // Check if a conversation already exists
    final docRef = FirebaseFirestore.instance.collection('conversations').doc(convoId);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      // Create a new conversation
      await docRef.set({
        'participants': [userId1, userId2],
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Created new conversation: $convoId');
    } else {
      print('Conversation already exists: $convoId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      PostsPage(uid: widget.uid),
      GroupsPage(uid: widget.uid),
      MessagesPage(uid: widget.uid),
    ];

    return Scaffold(
      appBar: AppBar(
      title: const Text('OtaijU'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchPage())),
        ),
      ],
    ),
      body: pages[selected],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selected,
        onTap: (i) => setState(() => selected = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'Publicaciones'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Grupos'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Mensajes'),
        ],
      ),
      floatingActionButton: selected == 0
          ? FloatingActionButton(
              onPressed: () => showDialog(context: context, builder: (_) => const CreatePostDialog()),
              child: const Icon(Icons.add_a_photo),
            )
          : null,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                color: Colors.deepOrange, // color de fondo naranja
                ),
                currentAccountPicture: Image.asset('lib/assets/logo.png'),
                accountName: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData || !snap.data!.exists) return const Text('Cargando...');
                      final data = snap.data!.data() as Map<String, dynamic>;
                      return Text(data['username'] ?? 'Usuario');
                    }),
                accountEmail: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData || !snap.data!.exists) return const Text('');
                      final data = snap.data!.data() as Map<String, dynamic>;
                      return Text(data['email'] ?? '');
                    }),
              ),
              ListTile(title: const Text('Mi perfil'), leading: const Icon(Icons.person), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(uid: widget.uid))); }),
              ListTile(title: const Text('Cerrar sesión'), leading: const Icon(Icons.logout), onTap: () async { await FirebaseAuth.instance.signOut(); }),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------ Posts Page ------------------
class PostsPage extends StatelessWidget {
  final String uid;
  const PostsPage({required this.uid, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const Center(child: Text("Usuario no encontrado."));
        }

        final userData = userSnap.data!.data() as Map<String, dynamic>;
        final following = List<String>.from(userData['following'] ?? []);
        final groupIds = List<String>.from(userData['groups'] ?? []);
        final authorsToFetch = [uid, ...following];

        final userPostsQuery = FirebaseFirestore.instance
            .collection('posts')
            .where('authorId', whereIn: authorsToFetch.isEmpty ? ['__none__'] : authorsToFetch)
            .orderBy('createdAt', descending: true);

        final groupPostsQuery = FirebaseFirestore.instance
            .collection('posts')
            .where('groupId', whereIn: groupIds.isEmpty ? ['__none__'] : groupIds)
            .orderBy('createdAt', descending: true);

        return StreamBuilder<QuerySnapshot>(
          stream: userPostsQuery.snapshots(),
          builder: (context, userPostsSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: groupPostsQuery.snapshots(),
              builder: (context, groupPostsSnapshot) {
                if (userPostsSnapshot.connectionState == ConnectionState.waiting || groupPostsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (userPostsSnapshot.hasError || groupPostsSnapshot.hasError) {
                  if(userPostsSnapshot.hasError) print("Error en userPostsQuery: ${userPostsSnapshot.error}");
                  if(groupPostsSnapshot.hasError) print("Error en groupPostsQuery: ${groupPostsSnapshot.error}");
                  return const Center(child: Text('Error al cargar publicaciones.'));
                }

                final userPosts = userPostsSnapshot.data?.docs ?? [];
                final groupPosts = groupPostsSnapshot.data?.docs ?? [];

                final allPosts = [...userPosts, ...groupPosts];
                allPosts.sort((a, b) {
                  final aTimestamp = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp? ?? Timestamp(0, 0);
                  final bTimestamp = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp? ?? Timestamp(0, 0);
                  return bTimestamp.compareTo(aTimestamp);
                });

                final uniquePosts = allPosts.fold<Map<String, DocumentSnapshot>>({}, (map, post) {
                  map[post.id] = post;
                  return map;
                }).values.toList();

                if (uniquePosts.isEmpty) {
                  return const Center(child: Text('No hay publicaciones aun.'));
                }

                                    return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: uniquePosts.length,
                  itemBuilder: (context, i) {
                    final d = uniquePosts[i];
                    final data = d.data() as Map<String, dynamic>;
                    return PostCard(postId: d.id, data: data);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class PostMedia extends StatefulWidget {
  final String mediaUrl;
  const PostMedia({super.key, required this.mediaUrl});

  @override
  State<PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<PostMedia> {
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    if (widget.mediaUrl.isNotEmpty) {
      try {
        final videoId = YoutubePlayer.convertUrlToId(widget.mediaUrl);
        if (videoId != null) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
              isLive: false,
            ),
          );
        }
      } catch (e) {
        print("Error converting YouTube URL: $e");
      }
    }
  }

  bool _isImageUrl(String url) {
    final lowercasedUrl = url.toLowerCase();
    return lowercasedUrl.endsWith('.jpg') ||
        lowercasedUrl.endsWith('.jpeg') ||
        lowercasedUrl.endsWith('.png') ||
        lowercasedUrl.endsWith('.gif') ||
        lowercasedUrl.endsWith('.webp') ||
        lowercasedUrl.endsWith('.bmp');
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_youtubeController != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.amber,
        ),
      );
    }

    if (_isImageUrl(widget.mediaUrl)) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Image.network(
          widget.mediaUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.error, color: Colors.red);
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Image.network(
        widget.mediaUrl ?? '',
        errorBuilder: (context, error, stackTrace) {
          return Row(
            children: [
              const Icon(Icons.link),
              const SizedBox(width: 8),
              Expanded(child: Text('Enlace: ${widget.mediaUrl}', overflow: TextOverflow.ellipsis)),
            ],
          );
        },
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> data;
  final bool showEditDelete;
  const PostCard({required this.postId, required this.data, this.showEditDelete = false, super.key});

  @override
  Widget build(BuildContext context) {
    final authorId = data['authorId'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(uid: authorId))),
                  child: Text('@${data['authorUsername'] ?? 'user'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text(data['createdAt'] == null ? '' : (data['createdAt'] as Timestamp).toDate().toString(), style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            if ((data['title'] ?? '').toString().isNotEmpty) Text(data['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if ((data['description'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top:8.0), child: Text(data['description'])),
            PostMedia(mediaUrl: data['mediaUrl'] ?? ''),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.thumb_up), onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  final likesRef = FirebaseFirestore.instance.collection('posts').doc(postId).collection('likes');
                  final likeDoc = await likesRef.doc(uid).get();
                  if (likeDoc.exists) {
                    await likesRef.doc(uid).delete();
                  } else {
                    await likesRef.doc(uid).set({'createdAt': FieldValue.serverTimestamp()});
                  }
                }),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('posts').doc(postId).collection('likes').snapshots(),
                  builder: (context, snap) { final c = snap.data?.docs.length ?? 0; return Text('$c'); },
                ),
                IconButton(icon: const Icon(Icons.comment), onPressed: () => showDialog(context: context, builder: (_) => CommentDialog(postId: postId))),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').snapshots(),
                  builder: (context, snap) { final c = snap.data?.docs.length ?? 0; return Text('$c'); },
                ),
                if (showEditDelete) ...[
                  const Spacer(),
                  PopupMenuButton<String>(onSelected: (v) async {
                    if (v == 'edit') {
                      showDialog(context: context, builder: (_) => EditPostDialog(postId: postId, data: data));
                    } else if (v == 'delete') {
                      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
                    }
                  }, itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Editar')), const PopupMenuItem(value: 'delete', child: Text('Eliminar'))]),
                ],
              ],
            )
          ],
        ),
      ),
    );
  }
}

class CreatePostDialog extends StatefulWidget {
  final String? groupId;
  const CreatePostDialog({this.groupId, super.key});

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _media = TextEditingController();
  bool loading = false;

  Future<void> _create() async {
    setState(() => loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final username = (userSnap.data() ?? {})['username'] ?? 'user';

    final postData = {
      'authorId': uid,
      'authorUsername': username,
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'mediaUrl': _media.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (widget.groupId != null) {
      postData['groupId'] = widget.groupId;
    }
    await FirebaseFirestore.instance.collection('posts').add(postData);

    setState(() => loading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear publicación'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título')),
            TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Descripción')),
            TextField(controller: _media, decoration: const InputDecoration(labelText: 'Enlace imagen/video (opcional)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: loading ? null : _create, child: loading ? const CircularProgressIndicator() : const Text('Crear')),
      ],
    );
  }
}

class CommentDialog extends StatefulWidget {
  final String postId;
  const CommentDialog({required this.postId, super.key});

  @override
  State<CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<CommentDialog> {
  final _comment = TextEditingController();

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final username = (userSnap.data() ?? {})['username'] ?? 'user';
    await FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments').add({
      'authorId': uid,
      'authorUsername': username,
      'text': _comment.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    _comment.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Comentarios'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments').orderBy('createdAt').snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const CircularProgressIndicator();
                  final docs = snap.data!.docs;
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      return ListTile(
                        title: GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(uid: d['authorId']))), child: Text(d['authorUsername'] ?? 'user')),
                        subtitle: Text(d['text'] ?? ''),
                      );
                    },
                  );
                },
              ),
            ),
            TextField(controller: _comment, decoration: const InputDecoration(labelText: 'Escribe un comentario')),
            ElevatedButton(onPressed: _send, child: const Text('Enviar')),
          ],
        ),
      ),
    );
  }
}

// ------------------ Groups ------------------
class GroupsPage extends StatelessWidget {
  final String uid;
  const GroupsPage({required this.uid, super.key});

  @override
  Widget build(BuildContext context) {
    final groupsRef = FirebaseFirestore.instance.collection('groups').orderBy('createdAt', descending: true);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              ElevatedButton.icon(onPressed: () => showDialog(context: context, builder: (_) => const CreateGroupDialog()), icon: const Icon(Icons.add), label: const Text('Crear grupo')),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: groupsRef.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final data = d.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: data['image'] != null && data['image'].toString().isNotEmpty ? Image.network(data['image'], width: 56, height: 56, fit: BoxFit.cover) : Image.asset('lib/assets/logo.png', width: 56, height: 56),
                    title: Text(data['title'] ?? 'Título'),
                    subtitle: Text('Miembros: ${(data['members'] as List? ?? []).length}'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailPage(groupId: d.id))),
                    trailing: Builder(
                      builder: (context) {
                        final isMember = (data['members'] as List? ?? []).contains(uid);
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMember ? Colors.red[400] : Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final docRef = FirebaseFirestore.instance.collection('groups').doc(d.id);
                            if (isMember) {
                              await docRef.update({'members': FieldValue.arrayRemove([uid])});
                            } else {
                              await docRef.update({'members': FieldValue.arrayUnion([uid])});
                            }
                          },
                          child: Text(isMember ? 'Abandonar' : 'Unirse'),
                        );
                      }
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});
  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _title = TextEditingController();
  final _image = TextEditingController();
  bool loading = false;

  Future<void> _create() async {
    setState(() => loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final username = (userSnap.data() ?? {})['username'] ?? 'user';
    await FirebaseFirestore.instance.collection('groups').add({
      'title': _title.text.trim(),
      'image': _image.text.trim(),
      'creatorId': uid,
      'creatorName': username,
      'members': [uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    setState(() => loading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear grupo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título del grupo')),
          TextField(controller: _image, decoration: const InputDecoration(labelText: 'Link imagen (opcional)')),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), ElevatedButton(onPressed: loading ? null : _create, child: loading ? const CircularProgressIndicator() : const Text('Crear'))],
    );
  }
}

class GroupDetailPage extends StatefulWidget {
  final String groupId;
  const GroupDetailPage({required this.groupId, super.key});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  bool _showMembers = false; // New state variable

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId); // Use widget.groupId
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>( // StreamBuilder is now the top-level widget
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const Center(child: CircularProgressIndicator());
        final data = snap.data!.data() as Map<String, dynamic>;
        final members = List<String>.from(data['members'] ?? []);
        final isMember = members.contains(currentUserId);

        return Scaffold( // Scaffold is now inside the builder
          appBar: AppBar(title: Text(data['title'] ?? 'Grupo')), // Use group title
          body: Column(
            children: [
              if ((data['image'] ?? '').toString().isNotEmpty) Image.network(data['image']),
              Text(data['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListTile(
                title: Text('Miembros: ${members.length}'),
                trailing: Icon(_showMembers ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                onTap: () {
                  setState(() {
                    _showMembers = !_showMembers;
                  });
                },
              ),
              if (_showMembers)
                Expanded(
                  child: ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, i) => FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(members[i]).get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData || !userSnap.data!.exists) return const ListTile(title: Text('Cargando...'));
                        final u = userSnap.data!.data() as Map<String, dynamic>;
                        return ListTile(title: Text(u['username'] ?? 'user'));
                      },
                    ),
                  ),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('posts').where('groupId', isEqualTo: widget.groupId).orderBy('createdAt', descending: true).snapshots(), // Use widget.groupId
                  builder: (context, postSnap) {
                    if (!postSnap.hasData) return const CircularProgressIndicator();
                    final docs = postSnap.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('No hay publicaciones en este grupo.'));
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i];
                        final postData = d.data() as Map<String, dynamic>;
                        final isMyPost = currentUserId == postData['authorId'];
                        return PostCard(
                          postId: d.id,
                          data: postData,
                          showEditDelete: isMyPost,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: currentUserId != null && isMember
              ? FloatingActionButton(
                  onPressed: () => showDialog(context: context, builder: (_) => CreatePostDialog(groupId: widget.groupId)), // Use widget.groupId
                  child: const Icon(Icons.add_a_photo),
                )
              : null,
        );
      },
    );
  }
}

// ------------------ Messages ------------------
class MessagesPage extends StatelessWidget {
  final String uid;
  const MessagesPage({required this.uid, super.key});

  @override
Widget build(BuildContext context) {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  return Scaffold(
    
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: uid) // solo los chats del usuario actual
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        
        if (docs.isEmpty) {
          return const Center(child: Text("No tienes chats aún."));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final participants = List<String>.from(d['participants'] ?? []);

            // obtenemos el otro participante
            final otherUserId = participants.firstWhere((p) => p != uid, orElse: () => "");

            // usamos FutureBuilder para traer su username
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const ListTile(
                    title: Text("Cargando usuario..."),
                  );
                }

                final userData = userSnap.data!.data() as Map<String, dynamic>?;
                final username = userData?['username'] ?? "Usuario desconocido";

                final lastMessage = d['lastMessage'] ?? "Sin mensajes todavía";

                return ListTile(
                  leading: const Icon(Icons.chat_bubble),
                  title: Text(username),
                  subtitle: Text(lastMessage),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          withId: otherUserId,
                          withUsername: username,
                        ),
                      ),
                    );
                  },
                );

              },
            );
          },
        );
      },
    ),
  );
}
}

class ChatPage extends StatefulWidget {
  final String withId;
  final String withUsername;
  const ChatPage({required this.withId, required this.withUsername, super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();

  Future<bool> _canMessage() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final me = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final them = await FirebaseFirestore.instance.collection('users').doc(widget.withId).get();
    final meFollowing = List<String>.from((me.data()?['following']) ?? []);
    final themFollowing = List<String>.from((them.data()?['following']) ?? []);
    return meFollowing.contains(widget.withId) && themFollowing.contains(me.id);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return FutureBuilder<bool>(
      future: _canMessage(),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final allowed = snap.data!;
        if (!allowed) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.withUsername)),
            body: const Center(child: Text('Ambos usuarios deben seguirse para enviar mensajes.')),
          );
        }

        final convoId = makeConversationId(uid, widget.withId);
        final messagesRef = FirebaseFirestore.instance
            .collection('conversations')
            .doc(convoId)
            .collection('messages')
            .orderBy('createdAt', descending: true);

        return Scaffold(
          appBar: AppBar(title: Text(widget.withUsername)),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: messagesRef.snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;

                    return ListView.builder(
                      reverse: true, // que los mensajes nuevos estén abajo
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final isMe = d['from'] == uid; // si el mensaje es mío

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue[200] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              d['text'] ?? '',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration: const InputDecoration(hintText: "Escribe un mensaje..."),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      if (_text.text.trim().isEmpty) return;

                      await FirebaseFirestore.instance
                          .collection('conversations')
                          .doc(convoId)
                          .collection('messages')
                          .add({
                        'from': uid,
                        'to': widget.withId,
                        'text': _text.text.trim(),
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      // actualizar lastMessage para mostrar en la lista de chats
                      await FirebaseFirestore.instance
                          .collection('conversations')
                          .doc(convoId)
                          .set({
                        'participants': [uid, widget.withId],
                        'lastMessage': _text.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));

                      _text.clear();
                    },
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }
}


/* String makeConversationId(String a, String b) => a.hashCode <= b.hashCode ? '\${a}_\${b}' : '\${b}_\${a}'; */

// ------------------ Profile ------------------
class ProfilePage extends StatefulWidget {
  final String uid;
  const ProfilePage({required this.uid, super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _toggleFollow(String targetUserId, bool isFollowing) async {
    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
    final targetUserRef = FirebaseFirestore.instance.collection('users').doc(targetUserId);

    if (isFollowing) {
      // Unfollow
      await currentUserRef.update({
        'following': FieldValue.arrayRemove([targetUserId])
      });
      await targetUserRef.update({
        'followers': FieldValue.arrayRemove([currentUserId])
      });
      // Also delete the conversation if it exists
      final convoId = makeConversationId(currentUserId!, targetUserId);
      await FirebaseFirestore.instance.collection('conversations').doc(convoId).delete();

      // Delete conversation subcollection documents for both users
      await currentUserRef.collection('conversations').doc(targetUserId).delete();
      await targetUserRef.collection('conversations').doc(currentUserId).delete();

    } else {
      // Follow
      await currentUserRef.update({
        'following': FieldValue.arrayUnion([targetUserId])
      });
      await targetUserRef.update({
        'followers': FieldValue.arrayUnion([currentUserId])
      });

      // Check for mutual follow and create chat
      /* final targetUserSnap = await targetUserRef.get();
      final targetUserFollowing = List<String>.from(targetUserSnap.data()?['following'] ?? []);

      if (targetUserFollowing.contains(currentUserId)) {
        // Mutual follow detected, create conversation
        final convoId = makeConversationId(currentUserId!, targetUserId);
        await FirebaseFirestore.instance.collection('conversations').doc(convoId).set({
          'participants': [currentUserId, targetUserId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '', // Initialize with empty last message
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });

        // Update conversations subcollection for both users
        await currentUserRef.collection('conversations').doc(targetUserId).set({
          'withId': targetUserId,
          'withUsername': targetUserSnap.data()?['username'] ?? 'user',
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });

        final currentUserSnap = await currentUserRef.get();
        await targetUserRef.collection('conversations').doc(currentUserId).set({
          'withId': currentUserId,
          'withUsername': currentUserSnap.data()?['username'] ?? 'user',
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });
      } */
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewedUserDocRef = FirebaseFirestore.instance.collection('users').doc(widget.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: viewedUserDocRef.snapshots(),
        builder: (context, viewedUserSnap) {
          if (!viewedUserSnap.hasData || !viewedUserSnap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final viewedUserData = viewedUserSnap.data!.data() as Map<String, dynamic>;
          final username = viewedUserData['username'] ?? '';
          final bio = viewedUserData['bio'] ?? '';
          final followingCount = (viewedUserData['following'] as List? ?? []).length;
          final followersCount = (viewedUserData['followers'] as List? ?? []).length;

          return Column(
            children: [
              const SizedBox(height: 12),
              Image.asset('lib/assets/logo.png', width: 120, height: 120),
              const SizedBox(height: 8),
              Text(username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(bio),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserListPage(
                              userIds: List<String>.from(viewedUserData['following'] ?? []),
                              title: 'Siguiendo',
                            ),
                          ),
                        );
                      },
                      child: Text('Siguiendo: $followingCount'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserListPage(
                              userIds: List<String>.from(viewedUserData['followers'] ?? []),
                              title: 'Seguidores',
                            ),
                          ),
                        );
                      },
                      child: Text('Seguidores: $followersCount'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              if (currentUserId != null && currentUserId != widget.uid) // Only show follow/unfollow if not own profile
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
                  builder: (context, currentUserSnap) {
                    if (!currentUserSnap.hasData || !currentUserSnap.data!.exists) {
                      return const SizedBox.shrink(); // Or a loading indicator
                    }
                    final currentUserData = currentUserSnap.data!.data() as Map<String, dynamic>;
                    final currentUserFollowing = List<String>.from(currentUserData['following'] ?? []);
                    final isFollowing = currentUserFollowing.contains(widget.uid);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ElevatedButton(
                        onPressed: () => _toggleFollow(widget.uid, isFollowing),
                        child: Text(isFollowing ? 'Dejar de seguir' : 'Seguir'),
                      ),
                    );
                  },
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('posts').where('authorId', isEqualTo: widget.uid).orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const CircularProgressIndicator();
                    final docs = snap.data!.docs;
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i];
                        final data = d.data() as Map<String, dynamic>;
                        final isMyPost = currentUserId == widget.uid; // Compare with the uid passed to ProfilePage
                        return PostCard(
                          postId: d.id,
                          data: data,
                          showEditDelete: isMyPost,
                        );
                      },
                    );
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

class EditPostDialog extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  const EditPostDialog({required this.postId, required this.data, super.key});

  @override
  State<EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<EditPostDialog> {
  late TextEditingController _title;
  late TextEditingController _desc;

  @override
  void initState() {
    _title = TextEditingController(text: widget.data['title']);
    _desc = TextEditingController(text: widget.data['description']);
    super.initState();
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance.collection('posts').doc(widget.postId).update({
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar publicación'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: _title), TextField(controller: _desc)]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')), ElevatedButton(onPressed: _save, child: const Text('Guardar'))],
    );
  }
  
}
class UserListPage extends StatelessWidget {
  final List<String> userIds;
  final String title;

  const UserListPage({required this.userIds, required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        itemCount: userIds.length,
        itemBuilder: (context, i) {
          final userId = userIds[i];
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
            builder: (context, userSnap) {
              if (!userSnap.hasData || !userSnap.data!.exists) {
                return const ListTile(title: Text('Usuario no encontrado'));
              }

              final userData = userSnap.data!.data() as Map<String, dynamic>;
              return ListTile(
                leading: Image.asset('lib/assets/logo.png', width: 40, height: 40), // Or a profile image if available
                title: Text(userData['username'] ?? 'Usuario'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(uid: userId))),
              );
            },
          );
        },
      ),
    );
  }
}
class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final _searchController = TextEditingController();
  List<String> _searchResults = [];
  bool _isLoading = false;

  Future<void> _searchUsers(String query) async {
    setState(() {
      _isLoading = true;
      _searchResults = []; // Clear previous results
    });

    if (query.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: query + '\uf0ff') // Unicode trick for range query
          .get();

      setState(() {
        _searchResults = querySnapshot.docs.map((doc) => doc.id).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isLoading = false;
        _searchResults = []; // Clear results on error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar usuarios'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre de usuario',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (query) {
                _searchUsers(query);
              },
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_searchResults.isEmpty)
              const Center(child: Text('No se encontraron usuarios.'))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final userId = _searchResults[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData || !userSnap.data!.exists) {
                          return const ListTile(title: Text('Usuario no encontrado'));
                        }

                        final userData = userSnap.data!.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: Image.asset('lib/assets/logo.png', width: 40, height: 40),
                          title: Text(userData['username'] ?? 'Usuario'),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(uid: userId))),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SelectUserForChatPage extends StatefulWidget {
  const SelectUserForChatPage({super.key});

  @override
  State<SelectUserForChatPage> createState() => _SelectUserForChatPageState();
}

class _SelectUserForChatPageState extends State<SelectUserForChatPage> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar Usuario para Chat')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
        builder: (context, currentUserSnap) {
          if (!currentUserSnap.hasData || !currentUserSnap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final currentUserData = currentUserSnap.data!.data() as Map<String, dynamic>;
          final currentUserFollowing = List<String>.from(currentUserData['following'] ?? []);

          if (currentUserFollowing.isEmpty) {
            return const Center(child: Text('No sigues a nadie.'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: currentUserFollowing).snapshots(),
            builder: (context, followedUsersSnap) {
              if (!followedUsersSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final followedUsers = followedUsersSnap.data!.docs;

              if (followedUsers.isEmpty) {
                return const Center(child: Text('No hay usuarios a los que sigues.'));
              }

              final List<Map<String, dynamic>> mutuallyFollowingUsers = [];
              for (var userDoc in followedUsers) {
                final userData = userDoc.data() as Map<String, dynamic>;
                final userFollowers = List<String>.from(userData['followers'] ?? []);
                if (userFollowers.contains(currentUserId)) {
                  mutuallyFollowingUsers.add({
                    'uid': userDoc.id,
                    'username': userData['username'] ?? 'Usuario',
                  });
                }
              }

              if (mutuallyFollowingUsers.isEmpty) {
                return const Center(child: Text('No hay usuarios que te sigan de vuelta.'));
              }

              return ListView.builder(
                itemCount: mutuallyFollowingUsers.length,
                itemBuilder: (context, index) {
                  final user = mutuallyFollowingUsers[index];
                  return ListTile(
                    title: Text(user['username']),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            withId: user['uid'],
                            withUsername: user['username'],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}