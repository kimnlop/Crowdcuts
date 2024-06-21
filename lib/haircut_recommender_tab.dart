// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, prefer_final_fields, use_build_context_synchronously, sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HaircutRecommenderTab extends StatefulWidget {
  @override
  _HaircutRecommenderTabState createState() => _HaircutRecommenderTabState();
}

class _HaircutRecommenderTabState extends State<HaircutRecommenderTab> {
  PageController _pageController = PageController();
  int _currentImageIndex = 0;
  List<PageController> _imageControllers = [];

  List<List<String>> options = [
    ['Gender Haircut', 'Male', 'Female'],
    ['Hair Length', 'Short', 'Medium', 'Long'],
    ['Face Shape', 'Oval', 'Round', 'Square', 'Heart', 'Diamond'],
    ['Hair Type', 'Straight', 'Wavy', 'Curly'],
    ['Hair Density', 'Thin', 'Medium', 'Thick'],
    ['Recommendations']
  ];
  List<int> _selectedOptions =
      List.filled(5, -1); // Initialize all selections as -1

  List<List<String>> images = [
    ["assets/male.png", "assets/female.png"],
    ["assets/short.png", "assets/medium.png", "assets/long.png"],
    [
      "assets/oval.png",
      "assets/round.png",
      "assets/square.png",
      "assets/heart.png",
      "assets/diamond.png"
    ],
    ["assets/straight.png", "assets/wavy.png", "assets/curly.png"],
    ["assets/thin.png", "assets/mediumDensity.png", "assets/thick.png"],
  ];

  // Mapping from prediction responses to images
  Map<String, String> predictionImageMap = {
    "Classic Side Part": "assets/ClassicSidePart.jpg",
    "Tousled Top with Thin Layers": "assets/TousledTopwithThinLayers.jpg",
    "Long Cascading Layers": "assets/LongCascadingLayers.jpg",
    "Textured Quiff": "assets/TexturedQuiff.jpg",
    "Buzz Cut with Precision Fade": "assets/BuzzCutwithPrecisionFade.jpg",
    "Pompadour Fade": "assets/PompadourFade.jpg",
    "Angled Bob with Soft Fringe": "assets/AngledBobwithSoftFringe.jpg",
    "Surfer Shag": "SurferShag.jpg",
    "Voluminous Waves with Deep Layers":
        "assets/VoluminousWavswithDeepLayers.jpg",
    "Full Bodied Curls with Layers": "assets/FullBodiedCurlswithLayers.jpg",
    "Grown Out Layers with Texture": "assets/GrownOutLayerswithTexture.jpg",
    "Mid-Length Cut with Dynamic Layers":
        "assets/Mid-LengthCutwithDynamicLayers.jpg",
    "Layered Lob with Face-Framing Bangs":
        "assets/LayeredLobwithFace-FramingBangs.jpg",
    "Short Pixie with Textured Layers":
        "assets/ShortPixiewithTexturedLayers.jpg",
    "Blunt Bob with Thick Fringe": "assets/BluntBobwithThickFringe.jpg",
    "Slicked Back Undercut": "assets/SlickedBackUndercut.jpg",
    "Chin-Length Bob with Wave": "assets/Chin-LengthBobwithWave.jpg",
    "Bro Flow": "assets/BroFlow.jpg"
  };

  @override
  void initState() {
    super.initState();
    _imageControllers = List.generate(images.length, (_) => PageController());
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _imageControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() async {
    if (_selectedOptions.contains(-1)) {
      // Show an alert if not all options are selected
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Incomplete'),
          content: const Text('Please select all options.'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red, // Red background for Cancel button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Prepare the data to be sent to the backend
    Map<String, String> data = {
      'Gender Haircut': options[0][_selectedOptions[0] + 1],
      'Hair Length': options[1][_selectedOptions[1] + 1],
      'Face Shape': options[2][_selectedOptions[2] + 1],
      'Hair Type': options[3][_selectedOptions[3] + 1],
      'Hair Density': options[4][_selectedOptions[4] + 1],
    };

    final response = await http.post(
      Uri.parse('https://adetml.onrender.com/predict'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'features': data}),
    );

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      String prediction = result['prediction'];
      String? imagePath = predictionImageMap[prediction];

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Recommended Haircut'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(prediction),
              if (imagePath != null) Image.asset(imagePath),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green, // Green background for OK button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to get recommendation.'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor:
                    Colors.red, // Red background for Error OK button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: PageView.builder(
              controller: _pageController,
              itemCount: options.length,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = 0; // Reset image index when page changes
                });
              },
              itemBuilder: (context, index) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 50), // Space for uniform alignment
                    if (index < options.length - 1)
                      Stack(
                        children: [
                          Container(
                            height: 200,
                            child: PageView.builder(
                              controller: _imageControllers[index],
                              onPageChanged: (imageIndex) {
                                setState(() {
                                  _currentImageIndex = imageIndex;
                                });
                              },
                              itemCount: images[index].length,
                              itemBuilder: (context, imageIndex) {
                                return Card(
                                  elevation: 4.0,
                                  margin: const EdgeInsets.all(8.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.asset(
                                      images[index][imageIndex],
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_currentImageIndex > 0)
                            Positioned(
                              left: 8.0,
                              top: 0.0,
                              bottom: 0.0,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back,
                                    color: Color(0xFF50727B)),
                                onPressed: () {
                                  _imageControllers[index].previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            ),
                          if (_currentImageIndex < images[index].length - 1)
                            Positioned(
                              right: 8.0,
                              top: 0.0,
                              bottom: 0.0,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_forward,
                                    color: Color(0xFF50727B)),
                                onPressed: () {
                                  _imageControllers[index].nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 20), // Space for uniform alignment
                    Center(
                      child: Text(
                        options[index][0],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF50727B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...List.generate(
                      options[index].length - 1,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedOptions[index] = i;
                              if (index < options.length - 1) {
                                _pageController.animateToPage(index + 1,
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOut);
                              }
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedOptions[index] == i
                                  ? const Color.fromRGBO(120, 160, 131, 0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedOptions[index] == i
                                    ? const Color(0xFF50727B)
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              options[index][i + 1],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF50727B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (index == options.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF50727B),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Get Recommendations',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
