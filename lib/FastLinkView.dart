import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class FastLinkView extends StatefulWidget {
  final String fastLinkToken;
  final String fastLinkURL;
  final String extraParams;

  const FastLinkView({
    required this.fastLinkToken,
    required this.fastLinkURL,
    this.extraParams = '',
    Key? key,
  }) : super(key: key);

  @override
  State<FastLinkView> createState() => _FastLinkViewState();
}

class _FastLinkViewState extends State<FastLinkView> {
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _configureWebView();
  }

  Future<String> _loadFastLink() async {
    final String fastLinkURL = "https://fl4.sandbox.yodlee.com/authenticate/restserver/fastlink";
    final accessToken = "Bearer ${widget.fastLinkToken}";

    // Compose extraParams string safe for HTML form input
    final safeExtraParams = widget.extraParams;

    return '''
      <html>
        <body>
          <form id="fastlink-form" action="${widget.fastLinkURL}" method="POST">
            <input name="accessToken" value="$accessToken" type="hidden"/>
            <input name="extraParams" value="$safeExtraParams" type="hidden"/>
          </form>
          <script type="text/javascript">
            window.onload = function () {
              document.getElementById('fastlink-form').submit();
            }
          </script>
        </body>
      </html>
    ''';
  }

  void _configureWebView() async {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => print('Loading progress: $progress%'),
          onNavigationRequest: (request) {
            print('Navigating to ${request.url}');
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) {
            print('Page finished loading: $url');
          },
        ),
      )
      ..addJavaScriptChannel(
        'YWebViewHandler',
        onMessageReceived: (JavaScriptMessage message) async {
          print('JS message: ${message.message}');

          try {
            final data = jsonDecode(message.message);

            if (data['type'] == 'OPEN_EXTERNAL_URL') {
              final url = data['data']['url'];
              if (url != null && await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
            }
          } catch (e) {
            print('Error parsing JS message: $e');
          }
        },
      );

    final htmlString = await _loadFastLink();

    _webViewController.loadRequest(
      Uri.parse(
        Uri.dataFromString(
          htmlString,
          mimeType: 'text/html',
          encoding: Encoding.getByName('utf-8'),
        ).toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FastLink')),
      body: WebViewWidget(controller: _webViewController),
    );
  }
}
