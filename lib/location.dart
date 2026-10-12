// import 'dart:async';
// import 'dart:ui';
// import 'package:flutter/material.dart';

// import 'package:geolocator/geolocator.dart';
// import 'package:dio/dio.dart';

// class LocationService {
//   /// ✅ 1. Permission Handle Function
//   static Future<bool> handleLocationPermission() async {
//     bool serviceEnabled;
//     LocationPermission permission;

//     // Location service check
//     serviceEnabled = await Geolocator.isLocationServiceEnabled();

//     if (!serviceEnabled) {
//       debugPrint("❌ Location service disabled");
//       return false;
//     }

//     // Permission check
//     permission = await Geolocator.checkPermission();

//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();

//       if (permission == LocationPermission.denied) {
//         debugPrint("❌ Location permission denied");
//         return false;
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       debugPrint("❌ Permission permanently denied");
//       return false;
//     }

//     return true;
//   }

//   /// ✅ 2. Latitude & Longitude se Address Return Karega
//   static Future<String> getAddressFromLatLng({
//     required double latitude,
//     required double longitude,
//   }) async {
//     try {
//       List<Placemark> placemarks = await placemarkFromCoordinates(
//         latitude,
//         longitude,
//       );

//       Placemark place = placemarks.first;

//       return "${place.locality}, "
//           "${place.administrativeArea}, "
//           "${place.country} - ";
//     } catch (e) {
//       return "❌ Address not found";
//     }
//   }

//   /// ✅ 3. Current Location + Address Return Karega
//   static Future<Map<String, dynamic>?> getCurrentLocationWithAddress() async {
//     try {
//       final hasPermission = await handleLocationPermission().timeout(
//         const Duration(seconds: 4),
//         onTimeout: () => false,
//       );

//       if (hasPermission) {
//         Position position = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.medium, // medium = faster fix on phones
//         ).timeout(const Duration(seconds: 8));

//         String address = await getAddressFromLatLng(
//           latitude: position.latitude,
//           longitude: position.longitude,
//         );

//         if (address.isNotEmpty && address != "❌ Address not found") {
//           return {
//             "latitude": position.latitude,
//             "longitude": position.longitude,
//             "address": address,
//             "precise": true,
//           };
//         }
//       }
//     } catch (e) {
//       debugPrint("❌ Geolocator/Geocoding Error: $e");
//     }

//     // Fallback to IP-based location
//     debugPrint("ℹ️ Falling back to IP-based location");
//     final ipLoc = await getIPLocation();
//     if (ipLoc != null) {
//       ipLoc["precise"] = false;
//       return ipLoc;
//     }
//     return null;
//   }

//   /// ✅ 4. Fallback to IP-based location lookup
//   static Future<Map<String, dynamic>?> getIPLocation() async {
//     try {
//       final dio = Dio();
//       final response = await dio.get('https://freeipapi.com/api/json').timeout(const Duration(seconds: 5));
//       if (response.statusCode == 200 && response.data != null) {
//         final data = response.data;
//         final city = data['cityName'] ?? '';
//         final region = data['regionName'] ?? '';
//         final country = data['countryName'] ?? '';
//         if (city.isNotEmpty && country.isNotEmpty) {
//           final addr = region.isNotEmpty ? "$city, $region, $country" : "$city, $country";
//           return {
//             "latitude": (data['latitude'] ?? 0.0) as double,
//             "longitude": (data['longitude'] ?? 0.0) as double,
//             "address": addr,
//           };
//         }
//       }
//     } catch (e) {
//       debugPrint("❌ IP Location Error: $e");
//     }
//     return null;
//   }

//   /// ✅ 5. Dialog showing location prompts
//   static Future<void> promptEnableLocation(BuildContext context, VoidCallback onRefresh) async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     LocationPermission permission = await Geolocator.checkPermission();

//     if (!context.mounted) return;

//     if (!serviceEnabled) {
//       showDialog(
//         context: context,
//         builder: (ctx) => Theme(
//           data: ThemeData.dark(),
//           child: AlertDialog(
//             backgroundColor: const Color(0xFF14141E),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(16),
//               side: const BorderSide(color: Color(0xFF2A2A3A)),
//             ),
//             title: const Row(
//               children: [
//                 Icon(Icons.location_off_rounded, color: Colors.amber, size: 24),
//                 SizedBox(width: 10),
//                 Text('Location Services Off', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//               ],
//             ),
//             content: const Text(
//               'WisePlayer uses location to show local weather and channel suggestions. Would you like to enable system location services?',
//               style: TextStyle(color: Colors.white70, fontSize: 14),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx),
//                 child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//               ),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFFE57373),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                 ),
//                 onPressed: () async {
//                   Navigator.pop(ctx);
//                   await Geolocator.openLocationSettings();
//                   Future.delayed(const Duration(seconds: 2), onRefresh);
//                 },
//                 child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
//               ),
//             ],
//           ),
//         ),
//       );
//     } else if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
//       showDialog(
//         context: context,
//         builder: (ctx) => Theme(
//           data: ThemeData.dark(),
//           child: AlertDialog(
//             backgroundColor: const Color(0xFF14141E),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(16),
//               side: const BorderSide(color: Color(0xFF2A2A3A)),
//             ),
//             title: const Row(
//               children: [
//                 Icon(Icons.gps_fixed_rounded, color: Color(0xFF00BCD4), size: 24),
//                 SizedBox(width: 10),
//                 Text('Precise Location Permission', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//               ],
//             ),
//             content: const Text(
//               'To show precise local area name and weather details, please grant location permissions.',
//               style: TextStyle(color: Colors.white70, fontSize: 14),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx),
//                 child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//               ),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF00BCD4),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                 ),
//                 onPressed: () async {
//                   Navigator.pop(ctx);
//                   if (permission == LocationPermission.deniedForever) {
//                     await Geolocator.openAppSettings();
//                   } else {
//                     await Geolocator.requestPermission();
//                   }
//                   Future.delayed(const Duration(milliseconds: 500), onRefresh);
//                 },
//                 child: const Text('Grant Permission', style: TextStyle(color: Colors.white)),
//               ),
//             ],
//           ),
//         ),
//       );
//     } else {
//       // Location is already fully enabled and granted
//       showDialog(
//         context: context,
//         builder: (ctx) => Theme(
//           data: ThemeData.dark(),
//           child: AlertDialog(
//             backgroundColor: const Color(0xFF14141E),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(16),
//               side: const BorderSide(color: Color(0xFF2A2A3A)),
//             ),
//             title: const Row(
//               children: [
//                 Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
//                 SizedBox(width: 10),
//                 Text('Precise Location Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//               ],
//             ),
//             content: const Text(
//               'Your precise location access is enabled and running.',
//               style: TextStyle(color: Colors.white70, fontSize: 14),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx),
//                 child: const Text('OK', style: TextStyle(color: Colors.white)),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//   }
// }
