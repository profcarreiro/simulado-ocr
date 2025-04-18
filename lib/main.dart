import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simulado OCR',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  bool _isCameraInitialized = false;
  String _recognizedText = "";

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    await _controller.initialize();
    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  Future<void> _takePictureAndRecognizeText() async {
    final directory = await getTemporaryDirectory();
    final imagePath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _controller.takePicture().then((file) async {
      final inputImage = InputImage.fromFilePath(file.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      setState(() {
        _recognizedText = recognizedText.text;
      });

      // Chamando a função para processar o cartão de resposta
      await _analisarCartaoSAS(file.path);

      textRecognizer.close();
    });
  }

  Future<void> _analisarCartaoSAS(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final imagem = img.decodeImage(bytes);

    if (imagem == null) {
      setState(() {
        _recognizedText = 'Erro ao processar imagem.';
      });
      return;
    }

    int questoesPorColuna = 45;
    int alternativas = 5;

    // Correções feitas aqui
    double larguraTemp = imagem.width / 2;
    int larguraColuna = larguraTemp.toInt();
    int alturaTotal = imagem.height;

    int margemTopo = 100;
    int margemEsquerdaColuna1 = 100;
    int margemEsquerdaColuna2 = larguraColuna + 100;

    double alturaTemp = (alturaTotal - margemTopo) / questoesPorColuna - 2;
    int alturaQuestao = alturaTemp.toInt();

    int larguraAlternativa = 70;

    List<String> respostas = [];

    for (int q = 0; q < 90; q++) {
      int coluna = q < 45 ? 1 : 2;
      int numeroQuestao = q + 1;
      int indexNaColuna = coluna == 1 ? q : q - 45;

      int y = margemTopo + indexNaColuna * alturaQuestao;
      int xBase = coluna == 1 ? margemEsquerdaColuna1 : margemEsquerdaColuna2;

      int maisEscuro = 999999;
      int alternativaMarcada = -1;

      for (int a = 0; a < alternativas; a++) {
        int x = xBase + a * larguraAlternativa;
        final pixel = imagem.getPixel(x, y);

        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        int brilho = ((r + g + b) ~/ 3).toInt();

        if (brilho < maisEscuro) {
          maisEscuro = brilho;
          alternativaMarcada = a;
        }
      }

      String letra = String.fromCharCode(65 + alternativaMarcada);
      respostas.add('$numeroQuestao - $letra');
    }

    setState(() {
      _recognizedText = respostas.join('\n');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simulado OCR')),
      body: Column(
        children: [
          if (_isCameraInitialized)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: CameraPreview(_controller),
            )
          else
            const Center(child: CircularProgressIndicator()),
          ElevatedButton(
            onPressed: _takePictureAndRecognizeText,
            child: const Text("Tirar Foto e Ler Texto"),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(_recognizedText),
            ),
          )
        ],
      ),
    );
  }
}