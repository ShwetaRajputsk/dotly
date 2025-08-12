import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'account.dart';
import 'custom_app_bar.dart';


class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userName;
  String? _userImageUrl;
  String _selectedCategory = 'All Notes';
  bool _isLoading = true;
  String? _errorMessage;
  bool _shouldUseFallback = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _categories = [
    'All Notes',
    'Night thoughts',
    'To-do',
    'Shopping List',
    'Ideas',
    'Work',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserProfile();
    _checkFirebaseConnection();
    _checkAndSetFallbackMode();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

    User? user = _auth.currentUser;
    if (user != null) {
      try {
          // Add timeout to prevent hanging
          final doc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get(const GetOptions(source: Source.cache))
              .timeout(const Duration(seconds: 10));
          
        if (doc.exists) {
          Map<String, dynamic>? data = doc.data();
          if (data != null) {
            setState(() {
              _userName = data['name'];
              _userImageUrl = data['imageUrl'];
                _isLoading = false;
              });
            } else {
              setState(() {
                _userName = 'User';
                _userImageUrl = null;
                _isLoading = false;
              });
            }
          } else {
            setState(() {
              _userName = 'User';
              _userImageUrl = null;
              _isLoading = false;
            });
        }
      } catch (e) {
          print('Error loading user profile from Firestore: $e');
          
          // Check if it's an index error
          if (e.toString().contains('index') || e.toString().contains('failed-precondition')) {
            setState(() {
              _errorMessage = 'Database index needs to be created for proper functionality';
              _userName = 'User';
              _userImageUrl = null;
              _isLoading = false;
            });
          } else {
            // Fallback to default values if Firestore fails
            setState(() {
              _userName = 'User';
              _userImageUrl = null;
              _isLoading = false;
            });
          }
        }
      } else {
        setState(() {
          _userName = 'Guest';
          _userImageUrl = null;
          _isLoading = false;
          _errorMessage = 'Please sign in to access your notes';
        });
      }
    } catch (e) {
      print('Error in _loadUserProfile: $e');
      setState(() {
        _errorMessage = 'Failed to load user profile';
        _userName = 'User';
        _userImageUrl = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkFirebaseConnection() async {
    try {
      // Check if we can reach Firestore
      await _firestore
          .collection('_health')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      
      print('Firebase connection successful');
    setState(() {
        _errorMessage = null;
      });
    } catch (e) {
      print('Firebase connection failed: $e');
      setState(() {
        _errorMessage = 'Connection to server failed. Working in offline mode.';
      });
      
      // Show offline mode notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Working in offline mode. Some features may be limited.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showIndexCreationHelp() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Database Index Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To display your notes properly, a database index needs to be created. This is a one-time setup.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'Steps to fix:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Click the link below'),
              Text('2. Sign in to Firebase Console'),
              Text('3. Click "Create Index"'),
              Text('4. Wait for index to build (may take a few minutes)'),
              Text('5. Restart the app'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Open the Firebase console link
                // Note: In a real app, you'd use url_launcher package
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please manually open Firebase Console and create the index'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              child: Text('Open Firebase Console'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  bool get _isOffline => _errorMessage != null && _errorMessage!.contains('offline');

  void _showAddNoteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Text('Add New Note'),
              if (_isOffline) ...[
                SizedBox(width: 8),
                Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                Text('Offline', style: TextStyle(fontSize: 12, color: Colors.orange)),
              ],
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isOffline)
                Container(
                  padding: EdgeInsets.all(8),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note will be saved locally and synced when connection is restored',
                          style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ListTile(
                leading: Icon(Icons.text_fields, color: Color(0xFF6366F1)),
                title: Text('Text Note'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateNoteDialog('text');
                },
              ),
              ListTile(
                leading: Icon(Icons.check_box, color: Color(0xFF6366F1)),
                title: Text('Todo List'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateNoteDialog('todo');
                },
              ),
              ListTile(
                leading: Icon(Icons.mic, color: Color(0xFF6366F1)),
                title: Text('Voice Note'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateNoteDialog('voice');
                },
              ),
              ListTile(
                leading: Icon(Icons.list, color: Color(0xFF6366F1)),
                title: Text('List Note'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateNoteDialog('list');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateNoteDialog(String noteType) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedCategory = _categories[1]; // Default to first non-"All Notes" category

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create ${noteType.toUpperCase()} Note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Note Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                if (noteType == 'text' || noteType == 'voice')
                  TextField(
                    controller: contentController,
                    decoration: InputDecoration(
                      labelText: 'Note Content',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                if (noteType == 'list')
                  Column(
                    children: [
                      TextField(
                        controller: contentController,
                        decoration: InputDecoration(
                          labelText: 'List Items (separate with commas)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                if (noteType == 'todo')
                  Column(
                    children: [
                      TextField(
                        controller: contentController,
                        decoration: InputDecoration(
                          labelText: 'Todo Items (separate with commas)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.where((cat) => cat != 'All Notes').map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedCategory = value!;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isNotEmpty) {
                  await _createNote(
                    titleController.text.trim(),
                    contentController.text.trim(),
                    noteType,
                    selectedCategory,
                  );
                  Navigator.pop(context);
                }
              },
              child: Text('Create'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createNote(String title, String content, String type, String category) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        Map<String, dynamic> noteData = {
          'title': title,
          'content': content,
          'type': type,
          'category': category,
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Add type-specific data
        if (type == 'list') {
          List<String> items = content.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          noteData['listItems'] = items;
        } else if (type == 'todo') {
          List<String> items = content.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          noteData['todoItems'] = items.map((item) => {'text': item, 'completed': false}).toList();
        }

        // Try to create note with timeout
        await _firestore
            .collection('notes')
            .add(noteData)
            .timeout(const Duration(seconds: 15));
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Force a refresh of the notes display
        setState(() {});
      }
    } catch (e) {
      print('Error creating note: $e');
      String errorMessage = 'Error creating note';
      
      if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your connection.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your authentication.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _createNote(title, content, type, category),
          ),
        ),
      );
    }
  }

  Future<void> _deleteNote(String noteId) async {
    try {
      await _firestore
          .collection('notes')
          .doc(noteId)
          .delete()
          .timeout(const Duration(seconds: 10));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Note deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting note: $e');
      String errorMessage = 'Error deleting note';
      
      if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your connection.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your authentication.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _deleteNote(noteId),
          ),
        ),
      );
    }
  }

  void _showEditNoteDialog(DocumentSnapshot noteDoc) {
    final titleController = TextEditingController(text: noteDoc['title']);
    final contentController = TextEditingController(text: noteDoc['content']);
    String selectedCategory = noteDoc['category'] ?? _categories[1];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Note Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(
                    labelText: 'Note Content',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.where((cat) => cat != 'All Notes').map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedCategory = value!;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isNotEmpty) {
                  await _updateNote(
                    noteDoc.id,
                    titleController.text.trim(),
                    contentController.text.trim(),
                    selectedCategory,
                  );
                  Navigator.pop(context);
                }
              },
              child: Text('Update'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateNote(String noteId, String title, String content, String category) async {
    try {
      await _firestore
          .collection('notes')
          .doc(noteId)
          .update({
        'title': title,
        'content': content,
        'category': category,
        'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 10));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Note updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating note: $e');
      String errorMessage = 'Error updating note';
      
      if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your connection.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your authentication.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _updateNote(noteId, title, content, category),
          ),
        ),
      );
    }
  }

  Color _getNoteColor(String category) {
    switch (category) {
      case 'Work':
        return Color(0xFFFFF6E7);
      case 'Ideas':
        return Color(0xFFF3F4FF);
      case 'To-do':
        return Color(0xFFE4F5DB);
      case 'Night thoughts':
        return Color(0xFFFCE7F3);
      case 'Shopping List':
        return Color(0xFFE5E7EB);
      default:
        return Color(0xFFF8FAFF);
    }
  }

  String _getNoteIcon(String type) {
    switch (type) {
      case 'text':
        return '📝';
      case 'list':
        return '📋';
      case 'todo':
        return '✅';
      case 'voice':
        return '🎤';
      default:
        return '📄';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFBFF),
      body: SafeArea(
        child: Column(
          children: [
            // Enhanced Top Navigation Bar
            Container(
              margin: EdgeInsets.all(12),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          _userName ?? 'User',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_isOffline)
                          Container(
                            margin: EdgeInsets.only(top: 6),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_off, size: 12, color: Colors.orange[700]),
                                SizedBox(width: 4),
                                Text(
                                  'Offline Mode',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFF8F9FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.refresh_rounded, color: Color(0xFF8D1CDF), size: 18),
                          onPressed: () async {
                            await _checkAndSetFallbackMode();
                            setState(() {});
                            _loadUserProfile();
                          },
                          tooltip: 'Refresh',
                          constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ),
                      SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AccountPage(),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Color(0xFF8D1CDF).withOpacity(0.2), width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: CircleAvatar(
                            backgroundImage: _userImageUrl != null && _userImageUrl!.isNotEmpty
                                ? NetworkImage(_userImageUrl!) as ImageProvider
                                : AssetImage('assets/images/assistant_icon.png'),
                            radius: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Enhanced Main Prompt Area
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF6366F1).withOpacity(0.1),
                        Color(0xFF8B5CF6).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color(0xFF6366F1).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ready to write something new?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Capture your thoughts, ideas, and memories',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.note_alt_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 12),

            // Enhanced Search Bar
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 12),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Color(0xFFF8F9FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.search_rounded,
                          color: Color(0xFF6366F1),
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search your notes...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFFF8F9FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: Color(0xFF6366F1),
                              size: 16,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            padding: EdgeInsets.all(6),
                            constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 12),

            // Enhanced Category Filters
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;
                      
                      return Container(
                        margin: EdgeInsets.only(right: 12),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: FilterChip(
                            label: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Color(0xFF6B7280),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                            backgroundColor: isSelected 
                                ? Color(0xFF6366F1) 
                                : Color(0xFFF3F4F6),
                            selectedColor: Color(0xFF6366F1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: isSelected ? 4 : 0,
                            shadowColor: isSelected 
                                ? Color(0xFF6366F1).withOpacity(0.3) 
                                : Colors.transparent,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            SizedBox(height: 12),

            // Dynamic Notes Stream
            Expanded(
              child: _isLoading 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Color(0xFFF8F9FF),
                            shape: BoxShape.circle,
                          ),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Loading your notes...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                          SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: TextStyle(fontSize: 16, color: Colors.red[600]),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          if (_errorMessage!.contains('sign in'))
                            Container(
                              margin: EdgeInsets.only(top: 8),
                              child: ElevatedButton(
                                onPressed: () {
                                  // Navigate to sign in page or show sign in dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Please sign in through the account section'),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                },
                                child: Text('Sign In'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            )
                          else if (_errorMessage!.contains('index'))
                            Container(
                              margin: EdgeInsets.only(top: 8),
                              child: ElevatedButton(
                                onPressed: _showIndexCreationHelp,
                                child: Text('Fix Index'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            )
                          else
                            Container(
                              margin: EdgeInsets.only(top: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: _loadUserProfile,
                                    child: Text('Retry'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF6366F1),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  ElevatedButton(
                                    onPressed: _checkFirebaseConnection,
                                    child: Text('Check Connection'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[600],
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadUserProfile();
                        await _checkFirebaseConnection();
                        await _checkAndSetFallbackMode();
                      },
                      child: _shouldUseFallback 
                        ? FutureBuilder<List<DocumentSnapshot>>(
                            future: _getNotesOnce(),
                            builder: (context, notesSnapshot) {
                              if (notesSnapshot.connectionState == ConnectionState.waiting) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFF8F9FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                          strokeWidth: 3,
                                        ),
                                      ),
                                      SizedBox(height: 20),
                                      Text(
                                        'Loading your notes...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              if (notesSnapshot.hasError) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                                      SizedBox(height: 16),
                                      Text(
                                        'Error loading notes',
                                        style: TextStyle(fontSize: 18, color: Colors.red[600]),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Database index needs to be created',
                                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: _showIndexCreationHelp,
                                        child: Text('Fix Index'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF6366F1),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              List<DocumentSnapshot> notes = notesSnapshot.data ?? [];
                              
                              // Filter notes by category if not "All Notes"
                              if (_selectedCategory != 'All Notes') {
                                notes = notes.where((note) => 
                                  note['category'] == _selectedCategory
                                ).toList();
                              }
                              
                              // Filter notes by search query
                              if (_searchQuery.isNotEmpty) {
                                notes = notes.where((note) {
                                  final title = (note['title'] ?? '').toString().toLowerCase();
                                  final content = (note['content'] ?? '').toString().toLowerCase();
                                  final searchLower = _searchQuery.toLowerCase();
                                  return title.contains(searchLower) || content.contains(searchLower);
                                }).toList();
                              }

                              if (notes.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFF8F9FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.note_add_rounded,
                                          size: 48,
                                          color: Color(0xFF6366F1).withOpacity(0.6),
                                        ),
                                      ),
                                      SizedBox(height: 24),
                                      Text(
                                        _searchQuery.isNotEmpty ? 'No notes found' : 'No notes yet',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        _searchQuery.isNotEmpty 
                                          ? 'Try adjusting your search terms'
                                          : 'Tap the + button to create your first note!',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey[600],
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              return Column(
                                children: [
                                  Expanded(
                                    child: GridView.builder(
                                      padding: EdgeInsets.symmetric(horizontal: 16),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 1.0, // Made even shorter to prevent overflow
                                      ),
                                      itemCount: notes.length,
                                      itemBuilder: (context, index) {
                                        final note = notes[index];
                                        return _buildNoteCard(note);
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                        : StreamBuilder<QuerySnapshot>(
                stream: _getNotesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Color(0xFFF8F9FF),
                              shape: BoxShape.circle,
                            ),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Loading your notes...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (snapshot.hasError) {
                                String errorMessage = 'Error loading notes';
                                bool isIndexError = snapshot.error.toString().contains('index') || 
                                                  snapshot.error.toString().contains('failed-precondition');
                                
                                // If it's an index error, switch to fallback mode
                                if (isIndexError) {
                                  _checkAndSetFallbackMode();
                    return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.refresh, size: 64, color: Colors.blue[300]),
                                        SizedBox(height: 16),
                                        Text(
                                          'Switching to fallback mode...',
                                          style: TextStyle(fontSize: 18, color: Colors.blue[600]),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Please wait while we load your notes',
                                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                                      SizedBox(height: 16),
                                      Text(
                                        errorMessage,
                                        style: TextStyle(fontSize: 18, color: Colors.red[600]),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Please check your connection and try again',
                                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {});
                                        },
                                        child: Text('Retry'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF6366F1),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Color(0xFFF8F9FF),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.note_add_rounded,
                              size: 48,
                              color: Color(0xFF6366F1).withOpacity(0.6),
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            _searchQuery.isNotEmpty ? 'No notes found' : 'No notes yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty 
                              ? 'Try adjusting your search terms'
                              : 'Tap the + button to create your first note!',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[600],
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  List<DocumentSnapshot> notes = snapshot.data!.docs;
                  
                  // Filter notes by category if not "All Notes"
                  if (_selectedCategory != 'All Notes') {
                    notes = notes.where((note) => 
                      note['category'] == _selectedCategory
                    ).toList();
                  }

                              // Filter notes by search query
                              if (_searchQuery.isNotEmpty) {
                                notes = notes.where((note) {
                                  final title = (note['title'] ?? '').toString().toLowerCase();
                                  final content = (note['content'] ?? '').toString().toLowerCase();
                                  final searchLower = _searchQuery.toLowerCase();
                                  return title.contains(searchLower) || content.contains(searchLower);
                                }).toList();
                              }

                  return GridView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.9, // Made shorter to prevent overflow
                    ),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return _buildNoteCard(note);
                    },
                  );
                },
                          ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF6366F1).withOpacity(0.3),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showAddNoteDialog,
          backgroundColor: Color(0xFF6366F1),
          elevation: 0,
          child: Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getNotesStream() {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        // First try with ordering, if it fails due to missing index, fall back to simple query
      return _firestore
          .collection('notes')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
            .snapshots()
            .handleError((error) {
          print('Firestore stream error: $error');
          
          // If index error, try without ordering
          if (error.toString().contains('index') || error.toString().contains('failed-precondition')) {
            print('Falling back to simple query without ordering');
            return _firestore
                .collection('notes')
                .where('userId', isEqualTo: user.uid)
                .snapshots()
                .handleError((fallbackError) {
              print('Fallback query also failed: $fallbackError');
              return Stream.empty();
            });
          }
          
          // Return an empty stream on other errors
          return Stream.empty();
        });
      } catch (e) {
        print('Error setting up Firestore stream: $e');
        return Stream.empty();
      }
    }
    return Stream.empty();
  }

  // Alternative method to get notes without streaming (for fallback)
  Future<List<DocumentSnapshot>> _getNotesOnce() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        // Try with ordering first
        try {
          final querySnapshot = await _firestore
              .collection('notes')
              .where('userId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .get();
          return querySnapshot.docs;
        } catch (e) {
          print('Ordered query failed, trying simple query: $e');
          // Fallback to simple query without ordering
          final querySnapshot = await _firestore
              .collection('notes')
              .where('userId', isEqualTo: user.uid)
              .get();
          return querySnapshot.docs;
        }
      } catch (e) {
        print('Error getting notes: $e');
        return [];
      }
    }
    return [];
  }

  // Check if we should use fallback mode
  Future<void> _checkAndSetFallbackMode() async {
    try {
      // Test if the ordered query works
      await _firestore
          .collection('notes')
          .where('userId', isEqualTo: _auth.currentUser?.uid ?? '')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      
      setState(() {
        _shouldUseFallback = false;
      });
    } catch (e) {
      print('Index check failed, using fallback mode: $e');
      setState(() {
        _shouldUseFallback = true;
      });
    }
  }

  Widget _buildNoteCard(DocumentSnapshot noteDoc) {
    final note = noteDoc.data() as Map<String, dynamic>;
    final noteColor = _getNoteColor(note['category'] ?? '');
    final noteIcon = _getNoteIcon(note['type'] ?? 'text');

    return GestureDetector(
      onTap: () => _showNoteDetail(noteDoc),
      child: Container(
        decoration: BoxDecoration(
          color: noteColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.8),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Note content
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          noteIcon,
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.grey[700],
                          size: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditNoteDialog(noteDoc);
                          } else if (value == 'delete') {
                            _showDeleteConfirmation(noteDoc.id);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 16, color: Color(0xFF8D1CDF)),
                                SizedBox(width: 10),
                                Text('Edit', style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 14)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded, size: 16, color: Colors.red[600]),
                                SizedBox(width: 10),
                                Text('Delete', style: TextStyle(color: Colors.red[600], fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    note['title'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6),
                  Expanded(
                    child: _buildNoteContent(note),
                  ),
                  SizedBox(height: 6),
                  // Tags section
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            note['category'] ?? '',
                            style: TextStyle(
                              fontSize: 8,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      // Additional tags
                      if (note['tags'] != null && (note['tags'] as List).isNotEmpty)
                        ...(note['tags'] as List).take(1).map((tag) => Container(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Color(0xFF6366F1).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Color(0xFF6366F1).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag.toString(),
                            style: TextStyle(
                              fontSize: 7,
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )).toList(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteContent(Map<String, dynamic> note) {
    final type = note['type'] ?? 'text';
    
    switch (type) {
      case 'list':
        final listItems = note['listItems'] as List<dynamic>? ?? [];
        if (listItems.isEmpty) return Text(
          'No items',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: listItems.take(2).map((item) {
            return Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 3,
                    margin: EdgeInsets.only(top: 5, right: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF4B5563),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      
      case 'todo':
        final todoItems = note['todoItems'] as List<dynamic>? ?? [];
        if (todoItems.isEmpty) return Text(
          'No todos',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: todoItems.take(2).map((item) {
            final isCompleted = item['completed'] ?? false;
            return Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 12,
                    color: isCompleted ? Color(0xFF10B981) : Color(0xFF6366F1),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item['text'] ?? '',
                      style: TextStyle(
                        fontSize: 10,
                        color: isCompleted ? Color(0xFF9CA3AF) : Color(0xFF4B5563),
                        height: 1.2,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        decorationColor: Color(0xFF9CA3AF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      
      case 'voice':
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Color(0xFF6366F1).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_filled_rounded,
                size: 14,
                color: Color(0xFF6366F1),
              ),
              SizedBox(width: 4),
              Text(
                'Voice note',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      
      default:
        final content = note['content'] ?? '';
        if (content.isEmpty) return Text(
          'No content',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        );
        return Text(
          content,
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF4B5563),
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
    }
  }

  void _showDeleteConfirmation(String noteId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Note'),
          content: Text('Are you sure you want to delete this note? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteNote(noteId);
              },
              child: Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNoteDetail(DocumentSnapshot noteDoc) {
    final note = noteDoc.data() as Map<String, dynamic>;
    final noteColor = _getNoteColor(note['category'] ?? '');
    final noteIcon = _getNoteIcon(note['type'] ?? 'text');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1A1A1A)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Note Detail',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.edit_rounded, color: Color(0xFF6366F1)),
                onPressed: () => _showEditNoteDialog(noteDoc),
              ),
              IconButton(
                icon: Icon(Icons.delete_rounded, color: Colors.red[600]),
                onPressed: () => _showDeleteConfirmation(noteDoc.id),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Note header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: noteColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              noteIcon,
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note['title'] ?? '',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  note['category'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (note['tags'] != null && (note['tags'] as List).isNotEmpty) ...[
                        SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (note['tags'] as List).map((tag) => Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Color(0xFF6366F1).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              tag.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 24),
                // Note content
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildFullNoteContent(note),
                ),
                SizedBox(height: 16),
                // Timestamp
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Created: ${_formatTimestamp(note['createdAt'])}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (note['updatedAt'] != null) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.update_rounded, size: 16, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Updated: ${_formatTimestamp(note['updatedAt'])}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullNoteContent(Map<String, dynamic> note) {
    final type = note['type'] ?? 'text';
    
    switch (type) {
      case 'list':
        final listItems = note['listItems'] as List<dynamic>? ?? [];
        if (listItems.isEmpty) return Text(
          'No items',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'List Items:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 12),
            ...listItems.map((item) {
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: EdgeInsets.only(top: 8, right: 12),
                      decoration: BoxDecoration(
                        color: Color(0xFF6366F1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4B5563),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      
      case 'todo':
        final todoItems = note['todoItems'] as List<dynamic>? ?? [];
        if (todoItems.isEmpty) return Text(
          'No todos',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Todo Items:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 12),
            ...todoItems.map((item) {
              final isCompleted = item['completed'] ?? false;
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: isCompleted ? Color(0xFF10B981) : Color(0xFF6366F1),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item['text'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          color: isCompleted ? Color(0xFF9CA3AF) : Color(0xFF4B5563),
                          height: 1.4,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          decorationColor: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      
      case 'voice':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice Note:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(0xFF6366F1).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_filled_rounded,
                    size: 32,
                    color: Color(0xFF6366F1),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice note',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Tap to play',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      
      default:
        final content = note['content'] ?? '';
        if (content.isEmpty) return Text(
          'No content',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        );
        return Text(
          content,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF4B5563),
            height: 1.6,
          ),
        );
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else {
        return 'Invalid date';
      }
      
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }
}

// Enhanced custom painter for the clipboard prompt illustration
