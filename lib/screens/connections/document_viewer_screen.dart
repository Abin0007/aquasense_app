import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DocumentViewerScreen extends StatelessWidget {
  final String url;

  const DocumentViewerScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    // Check if the URL likely points to a PDF
    final bool isPdf = url.toLowerCase().contains('.pdf');

    return Scaffold(
      appBar: AppBar(
        title: Text(isPdf ? 'PDF Viewer' : 'Image Viewer'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      // Use a different background color for PDFs for better contrast
      backgroundColor: isPdf ? Colors.white : Colors.black,
      body: isPdf
          ? SfPdfViewer.network(url)
          : Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            url,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: Icon(Icons.error, color: Colors.red));
            },
          ),
        ),
      ),
    );
  }
}