import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../utils/theme.dart';
import '../../utils/formatters.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  static const categories = [
    'Rent',
    'Salary',
    'Utility',
    'Stationery',
    'Marketing',
    'Maintenance',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseDialog(context),
        child: const Icon(Icons.add),
      ),
      body: finance.expenses.isEmpty
          ? const Center(child: Text('No expenses recorded yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: finance.expenses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = finance.expenses[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x1AE5484D),
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        color: kAccentRed,
                      ),
                    ),
                    title: Text(
                      e.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${e.category} • ${fmtDate(e.date)}'),
                    trailing: Text(
                      fmtMoney(e.amount),
                      style: const TextStyle(
                        color: kAccentRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onLongPress: () => _confirmDelete(context, finance, e.id),
                  ),
                );
              },
            ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    FinanceProvider finance,
    String id,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              finance.deleteExpense(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: kAccentRed)),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = categories.first;
    final finance = context.read<FinanceProvider>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (titleCtrl.text.trim().isEmpty || amount == null) return;
                finance.addExpense(
                  title: titleCtrl.text.trim(),
                  amount: amount,
                  category: category,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
