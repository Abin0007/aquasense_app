import 'package:aquasense/models/user_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart'; // Import DropdownSearch
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:aquasense/utils/location_service.dart'; // For fetching location names
import 'package:flutter_animate/flutter_animate.dart'; // Ensure flutter_animate is imported

class UserDetailScreen extends StatefulWidget {
  final String userId; // Receive user ID instead of the full object
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  // --- State for Ward Selection Dialog ---
  final LocationService _locationService = LocationService();
  List<String> _dialogStates = [];
  List<String> _dialogDistricts = [];
  List<String> _dialogWards = [];
  String? _dialogSelectedState;
  String? _dialogSelectedDistrict;
  String? _dialogSelectedWard;
  bool _isDialogLoadingStates = false;
  bool _isDialogLoadingDistricts = false;
  bool _isDialogLoadingWards = false;
  // --- End Ward State ---


  @override
  void initState() {
    super.initState();
    // Load states once for the dialog
    _loadDialogStates();
  }

  // --- Functions to load location data for the dialog ---
  Future<void> _loadDialogStates() async {
    if (!mounted) return;
    setState(() => _isDialogLoadingStates = true);
    final loadedStates = await _locationService.getStates();
    if (mounted) {
      setState(() {
        _dialogStates = loadedStates;
        _isDialogLoadingStates = false;
      });
    }
  }

  Future<void> _loadDialogDistricts(String state, Function setDialogState) async {
    if (!mounted) return;
    setDialogState(() => _isDialogLoadingDistricts = true);
    final loadedDistricts = await _locationService.getDistricts(state);
    if (mounted) {
      setDialogState(() {
        _dialogDistricts = loadedDistricts;
        _isDialogLoadingDistricts = false;
      });
    }
  }

  Future<void> _loadDialogWards(String state, String district, Function setDialogState) async {
    if (!mounted) return;
    setDialogState(() => _isDialogLoadingWards = true);
    final loadedWards = await _locationService.getWards(state, district);
    if (mounted) {
      setDialogState(() {
        _dialogWards = loadedWards;
        _isDialogLoadingWards = false;
      });
    }
  }
  // --- End Location Functions ---


  // --- MODIFIED Function to show role update dialog ---
  void _showUpdateRoleDialog(UserData currentUserData) {
    // Only allow changing between citizen and supervisor
    final List<String> availableRoles = ['citizen', 'supervisor'];

    // Ensure the current role is valid for this dialog, otherwise default
    String? roleToUpdate = availableRoles.contains(currentUserData.role)
        ? currentUserData.role
        : null; // Or set a default like 'citizen' if preferred

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder( // Use StatefulBuilder to update dialog state
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C5364),
              title: const Text('Update User Role', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                // Use the filtered list of roles
                children: availableRoles
                    .map((String role) => RadioListTile<String>(
                  // *** UPDATED: RadioListTile Usage ***
                  title: Text(role.toUpperCase(), style: const TextStyle(color: Colors.white)),
                  value: role,
                  groupValue: roleToUpdate,
                  onChanged: (String? value) {
                    setDialogState(() {
                      roleToUpdate = value;
                    });
                  },
                  activeColor: Colors.cyanAccent,
                  // *** UPDATED: Use resolveWith for fillColor ***
                  fillColor: MaterialStateColor.resolveWith((states) =>
                  states.contains(MaterialState.selected)
                      ? Colors.cyanAccent
                      : Colors.white54), // Provide color for unselected state too
                  controlAffinity: ListTileControlAffinity.trailing,
                  // *****************************************
                ))
                    .toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: (roleToUpdate != null && roleToUpdate != currentUserData.role)
                      ? () {
                    Navigator.of(dialogContext).pop();
                    _updateUserData({'role': roleToUpdate});
                  }
                      : null, // Disable if no change or null
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Update Role'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // --- END MODIFIED ROLE DIALOG ---


  // --- Function to show Ward Assignment Dialog ---
  void _showAssignWardDialog(UserData currentUserData) {
    // Reset dialog state when opening
    _dialogSelectedState = null;
    _dialogSelectedDistrict = null;
    _dialogSelectedWard = null;
    _dialogDistricts = [];
    _dialogWards = [];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool canUpdate = _dialogSelectedWard != null && _dialogSelectedWard != currentUserData.wardId;

            return AlertDialog(
              backgroundColor: const Color(0xFF2C5364),
              title: const Text('Assign User Ward', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView( // Ensure content is scrollable
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // State Dropdown
                    DropdownSearch<String>(
                      popupProps: PopupProps.menu(
                          showSearchBox: true,
                          menuProps: const MenuProps(backgroundColor: Color(0xFF2C5364)), // Corrected
                          searchFieldProps: TextFieldProps(
                              style: const TextStyle(color: Colors.black), // Style for search input text
                              decoration: InputDecoration(
                                hintText: "Search State",
                                filled: true,
                                fillColor: Colors.white.withAlpha(204), // 80% Opacity
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              )
                          ),
                          // Style for items in the dropdown list
                          itemBuilder: (context, item, isSelected) => ListTile(
                            title: Text(item, style: const TextStyle(color: Colors.white)),
                          )
                      ),
                      items: _dialogStates,
                      enabled: !_isDialogLoadingStates,
                      dropdownDecoratorProps: _getDropdownStyle(
                          _isDialogLoadingStates ? "Loading States..." : "Select State",
                          Icons.map_outlined),
                      onChanged: (value) {
                        if (value != null && value != _dialogSelectedState) {
                          // Reset lower levels and load districts
                          _loadDialogDistricts(value, setDialogState);
                          setDialogState(() {
                            _dialogSelectedState = value;
                            _dialogSelectedDistrict = null;
                            _dialogSelectedWard = null;
                            _dialogDistricts = [];
                            _dialogWards = [];
                          });
                        }
                      },
                      selectedItem: _dialogSelectedState,
                    ),
                    const SizedBox(height: 16),

                    // District Dropdown (conditional)
                    if (_dialogSelectedState != null)
                      DropdownSearch<String>(
                        popupProps: PopupProps.menu(
                            showSearchBox: true,
                            menuProps: const MenuProps(backgroundColor: Color(0xFF2C5364)), // Corrected
                            searchFieldProps: TextFieldProps(
                                style: const TextStyle(color: Colors.black), // Style for search input text
                                decoration: InputDecoration(
                                  hintText: "Search District",
                                  filled: true,
                                  fillColor: Colors.white.withAlpha(204), // 80% Opacity
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                )
                            ),
                            // Style for items in the dropdown list
                            itemBuilder: (context, item, isSelected) => ListTile(
                              title: Text(item, style: const TextStyle(color: Colors.white)),
                            )
                        ),
                        items: _dialogDistricts,
                        enabled: !_isDialogLoadingDistricts && _dialogDistricts.isNotEmpty,
                        dropdownDecoratorProps: _getDropdownStyle(
                            _isDialogLoadingDistricts ? "Loading Districts..." : (_dialogDistricts.isEmpty ? "No Districts Found" : "Select District"),
                            Icons.location_city),
                        onChanged: (value) {
                          if (value != null && value != _dialogSelectedDistrict) {
                            _loadDialogWards(_dialogSelectedState!, value, setDialogState);
                            setDialogState(() {
                              _dialogSelectedDistrict = value;
                              _dialogSelectedWard = null;
                              _dialogWards = [];
                            });
                          }
                        },
                        selectedItem: _dialogSelectedDistrict,
                      ),
                    const SizedBox(height: 16),

                    // Ward Dropdown (conditional)
                    if (_dialogSelectedDistrict != null)
                      DropdownSearch<String>(
                        popupProps: PopupProps.menu(
                            showSearchBox: true,
                            menuProps: const MenuProps(backgroundColor: Color(0xFF2C5364)), // Corrected
                            searchFieldProps: TextFieldProps(
                                style: const TextStyle(color: Colors.black), // Style for search input text
                                decoration: InputDecoration(
                                  hintText: "Search Ward",
                                  filled: true,
                                  fillColor: Colors.white.withAlpha(204), // 80% Opacity
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                )
                            ),
                            // Style for items in the dropdown list
                            itemBuilder: (context, item, isSelected) => ListTile(
                              title: Text(item, style: const TextStyle(color: Colors.white)),
                            )
                        ),
                        items: _dialogWards,
                        enabled: !_isDialogLoadingWards && _dialogWards.isNotEmpty,
                        dropdownDecoratorProps: _getDropdownStyle(
                            _isDialogLoadingWards ? "Loading Wards..." : (_dialogWards.isEmpty ? "No Wards Found" : "Select Ward"),
                            Icons.maps_home_work_outlined),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => _dialogSelectedWard = value);
                          }
                        },
                        selectedItem: _dialogSelectedWard,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: canUpdate
                      ? () {
                    Navigator.of(dialogContext).pop();
                    _updateUserData({'wardId': _dialogSelectedWard});
                  }
                      : null, // Disable if no valid ward selected or no change
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey.withAlpha(128) // 50% Opacity
                  ),
                  child: const Text('Assign Ward'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // --- End Ward Assignment Dialog ---

  // --- Function to handle user deletion request ---
  Future<void> _requestUserDeletion(UserData userData) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    bool? confirmRequest = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        title: const Text('Request User Deletion?', style: TextStyle(color: Colors.orangeAccent)),
        content: Text(
            'This will flag ${userData.name} for permanent deletion. This action requires confirmation and cannot be undone easily. Are you sure?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('FLAG FOR DELETION', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmRequest == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userData.uid)
            .update({'deletionRequested': true, 'deletionRequestedAt': FieldValue.serverTimestamp()});

        // Optionally show a success message or navigate back
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('${userData.name} flagged for deletion.'), backgroundColor: Colors.orange),
          );
          navigator.pop(); // Go back after flagging
        }

      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error flagging user: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }


  // --- Generic function to update user data ---
  Future<void> _updateUserData(Map<String, dynamic> dataToUpdate) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update(dataToUpdate);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('User data updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to update user: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
    // No need to call setState here as StreamBuilder will rebuild
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: const Color(0xFF152D4E),
        actions: [
          // Add delete/flag button here, only shown when data is loaded
          StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData = UserData.fromFirestore(snapshot.data!);
                  // Check if deletionRequested field exists and is true
                  final dataMap = snapshot.data!.data() as Map<String, dynamic>?;
                  final bool alreadyFlagged = dataMap?.containsKey('deletionRequested') ?? false && dataMap!['deletionRequested'] == true;

                  // Do not show the button for admin users
                  if (userData.role == 'admin') {
                    return const SizedBox.shrink();
                  }

                  return IconButton(
                    icon: Icon(
                      alreadyFlagged ? Icons.restore_from_trash_outlined : Icons.delete_forever_outlined,
                      color: alreadyFlagged ? Colors.grey : Colors.redAccent,
                    ),
                    tooltip: alreadyFlagged ? 'Undo Deletion Request' : 'Flag User for Deletion', // Updated tooltip
                    // --- Allow undoing the flag ---
                    onPressed: () => alreadyFlagged
                        ? _updateUserData({'deletionRequested': false, 'deletionRequestedAt': FieldValue.delete()}) // Unflag
                        : _requestUserDeletion(userData), // Flag
                  );
                }
                return const SizedBox.shrink(); // Return empty space while loading or if user doesn't exist
              }
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // Use stream to get real-time updates
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User not found.', style: TextStyle(color: Colors.white70)));
          }

          final userData = UserData.fromFirestore(snapshot.data!);
          // Check if deletionRequested field exists and is true
          final dataMap = snapshot.data!.data() as Map<String, dynamic>?;
          final bool isFlaggedForDeletion = dataMap?.containsKey('deletionRequested') ?? false && dataMap!['deletionRequested'] == true;


          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildProfileHeader(userData),
              const SizedBox(height: 30),
              // Show deletion flag message if applicable
              if(isFlaggedForDeletion) ...[
                Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: Colors.orangeAccent.withAlpha(38), // 15% Opacity
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orangeAccent)
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This user is flagged for deletion.',
                            style: TextStyle(color: Colors.orangeAccent[100]),
                          ),
                        ),
                      ],
                    )
                ),
              ],
              _buildDetailItem(Icons.email_outlined, "Email", userData.email),
              _buildDetailItem(Icons.phone_outlined, "Phone", userData.phoneNumber ?? 'Not Provided',
                trailing: Icon(
                  userData.isPhoneVerified ? Icons.verified_user : Icons.unpublished,
                  color: userData.isPhoneVerified ? Colors.greenAccent : Colors.grey,
                  size: 20,
                ),
              ),
              _buildDetailItem(Icons.location_city_outlined, "Ward ID", userData.wardId.isEmpty ? 'Not Assigned' : userData.wardId),
              _buildDetailItem(Icons.calendar_today_outlined, "Member Since", DateFormat('d MMMM, yyyy').format(userData.createdAt.toDate())),
              _buildDetailItem(Icons.water_damage_outlined, "Connection Status", userData.hasActiveConnection ? 'Active' : 'Inactive',
                  valueColor: userData.hasActiveConnection ? Colors.greenAccent : Colors.orangeAccent
              ),
              const Divider(height: 40, color: Colors.white24),

              // --- Admin Actions ---
              // Only show role update if the user is NOT an admin
              if (userData.role != 'admin')
                _buildAdminActionCard(
                  title: 'User Role',
                  currentValue: userData.role.toUpperCase(),
                  icon: Icons.security_outlined,
                  onTap: () => _showUpdateRoleDialog(userData), // Pass current data
                ),
              if (userData.role != 'admin') const SizedBox(height: 16),
              _buildAdminActionCard(
                title: 'Assign Ward',
                currentValue: userData.wardId.isEmpty ? 'Tap to assign' : userData.wardId,
                icon: Icons.map_outlined,
                onTap: () => _showAssignWardDialog(userData),
              ),

              // Add more details or actions as needed
            ].animate(interval: 50.ms).fadeIn(duration: 300.ms).slideX(begin: -0.1), // Animate list items
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(UserData userData) {
    ImageProvider backgroundImage;
    if (userData.profileImageUrl != null && userData.profileImageUrl!.isNotEmpty) {
      backgroundImage = NetworkImage(userData.profileImageUrl!);
    } else {
      // Use a default icon/placeholder if no image
      backgroundImage = const AssetImage('assets/icon/app_icon.png'); // Or use Icons.person
    }
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.white.withAlpha(30), // 12% Opacity approx
          backgroundImage: backgroundImage,
          // Handle potential errors loading network image
          onBackgroundImageError: (_, __) {
            // Optionally set a flag to show a placeholder icon if needed
          },
          child: backgroundImage is AssetImage || userData.profileImageUrl == null || userData.profileImageUrl!.isEmpty
              ? const Icon(Icons.person, size: 50, color: Colors.white70) // Placeholder Icon
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          userData.name,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          userData.role.toUpperCase(), // Display role below name
          style: TextStyle(
              color: _getRoleColor(userData.role), // Use a helper for color
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms); // Animate header
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return Colors.redAccent;
      case 'supervisor': return Colors.purpleAccent;
      default: return Colors.cyanAccent; // citizen
    }
  }

  Widget _buildDetailItem(IconData icon, String label, String value, {Color? valueColor, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 16),
          Text('$label:', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ]
        ],
      ),
    );
  }

  Widget _buildAdminActionCard({
    required String title,
    required String currentValue,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white.withAlpha(25), // ~10% Opacity
      child: ListTile(
        leading: Icon(icon, color: Colors.cyanAccent),
        title: Text(title, style: const TextStyle(color: Colors.white70)),
        subtitle: Text(currentValue, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.edit_outlined, color: Colors.white54),
        onTap: onTap,
      ),
    );
  }

  // --- Helper for Dropdown Styles (applied to dropdown itself) ---
  DropDownDecoratorProps _getDropdownStyle(String hint, IconData icon) {
    return DropDownDecoratorProps(
      baseStyle: const TextStyle(color: Colors.white), // Ensure dropdown text is white
      dropdownSearchDecoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.black.withAlpha(77), // 30% Opacity approx
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white30)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.cyanAccent)),
      ),
    );
  }
// --- End Helper ---
}