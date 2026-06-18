import 'package:flutter/material.dart';
import 'loading_widget.dart';
import 'empty_state.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final bool isLoading;
  final String? emptyMessage;
  final bool isEmpty;
  final IconData? emptyIcon;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final List<Widget>? actions;
  final bool showBack;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.isLoading = false,
    this.emptyMessage,
    this.isEmpty = false,
    this.emptyIcon,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.actions,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: actions,
      ),
      body: _buildBody(),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  Widget _buildBody() {
    if (isLoading) return const LoadingWidget();
    if (isEmpty) {
      return EmptyState(
        icon: emptyIcon ?? Icons.inbox_outlined,
        message: emptyMessage,
      );
    }
    return body;
  }
}
