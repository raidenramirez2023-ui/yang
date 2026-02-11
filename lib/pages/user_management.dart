import 'package:flutter/material.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  // Staff data
  List<Map<String, dynamic>> staffList = [
    {
      'name': 'Juan Dela Cruz',
      'age': 28,
      'address': '123 Main St, Quezon City',
      'sex': 'Male',
      'contact': '09123456789',
      'email': 'juan.delacruz@example.com',
      'maritalStatus': 'Single',
    },
    {
      'name': 'Maria Santos',
      'age': 35,
      'address': '456 Oak St, Makati',
      'sex': 'Female',
      'contact': '09187654321',
      'email': 'maria.santos@example.com',
      'maritalStatus': 'Married',
    },
    {
      'name': 'Roberto Garcia',
      'age': 42,
      'address': '789 Pine St, Taguig',
      'sex': 'Male',
      'contact': '09111222333',
      'email': 'roberto.garcia@example.com',
      'maritalStatus': 'Married',
    },
    {
      'name': 'Andrea Reyes',
      'age': 31,
      'address': '321 Elm St, Mandaluyong',
      'sex': 'Female',
      'contact': '09444555666',
      'email': 'andrea.reyes@example.com',
      'maritalStatus': 'Single',
    },
    {
      'name': 'Miguel Lopez',
      'age': 45,
      'address': '654 Maple St, Pasig',
      'sex': 'Male',
      'contact': '09777888999',
      'email': 'miguel.lopez@example.com',
      'maritalStatus': 'Married',
    },
    {
      'name': 'Elena Mendoza',
      'age': 29,
      'address': '987 Cedar St, San Juan',
      'sex': 'Female',
      'contact': '09000111222',
      'email': 'elena.mendoza@example.com',
      'maritalStatus': 'Single',
    },
    {
      'name': 'Antonio Castro',
      'age': 38,
      'address': '159 Birch St, Manila',
      'sex': 'Male',
      'contact': '09333444555',
      'email': 'antonio.castro@example.com',
      'maritalStatus': 'Married',
    },
    {
      'name': 'Sofia Aquino',
      'age': 33,
      'address': '753 Walnut St, Pasay',
      'sex': 'Female',
      'contact': '09666777888',
      'email': 'sofia.aquino@example.com',
      'maritalStatus': 'Single',
    },
    {
      'name': 'Carlos Lim',
      'age': 40,
      'address': '951 Spruce St, Muntinlupa',
      'sex': 'Male',
      'contact': '09999888777',
      'email': 'carlos.lim@example.com',
      'maritalStatus': 'Married',
    },
    {
      'name': 'Isabel Tan',
      'age': 27,
      'address': '357 Cherry St, Paranaque',
      'sex': 'Female',
      'contact': '09222111000',
      'email': 'isabel.tan@example.com',
      'maritalStatus': 'Single',
    },
    {
      'name': 'Diego Ramos',
      'age': 36,
      'address': '852 Willow St, Quezon City',
      'sex': 'Male',
      'contact': '09198887766',
      'email': 'diego.ramos@example.com',
      'maritalStatus': 'Married',
    },
    {
      'name': 'Laura Villanueva',
      'age': 30,
      'address': '753 Oakwood St, Makati',
      'sex': 'Female',
      'contact': '09443332211',
      'email': 'laura.villanueva@example.com',
      'maritalStatus': 'Single',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(Colors.grey.shade200),
                columnSpacing: 24,
                dataRowHeight: 60,
                columns: const [
                  DataColumn(
                      label: Text('Name',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Age',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Address',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Sex',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Contact',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Email',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Marital Status',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Actions',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: staffList.map((staff) {
                  return DataRow(cells: [
                    DataCell(Text(staff['name'])),
                    DataCell(Text(staff['age'].toString())),
                    DataCell(Text(staff['address'])),
                    DataCell(Text(staff['sex'])),
                    DataCell(Text(staff['contact'])),
                    DataCell(Text(staff['email'])),
                    DataCell(Text(staff['maritalStatus'])),
                    DataCell(Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            // Edit dialog
                            _showEditDialog(context, staff);
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.yellow.shade700,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Delete confirmation
                            _showDeleteDialog(context, staff);
                          },
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------
  // Edit staff dialog
  // -----------------------------
  void _showEditDialog(BuildContext context, Map<String, dynamic> staff) {
    TextEditingController nameController =
        TextEditingController(text: staff['name']);
    TextEditingController ageController =
        TextEditingController(text: staff['age'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Staff'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: ageController, decoration: const InputDecoration(labelText: 'Age'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                staff['name'] = nameController.text;
                staff['age'] = int.tryParse(ageController.text) ?? staff['age'];
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // Delete staff confirmation
  // -----------------------------
  void _showDeleteDialog(BuildContext context, Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text('Are you sure you want to delete ${staff['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                staffList.remove(staff);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
