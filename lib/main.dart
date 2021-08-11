import 'dart:async';
import 'dart:collection';
import 'package:geocode/geocode.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mt;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Maps',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapView(),
    );
  }
}

class MapView extends StatefulWidget {
  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  Position? _currentPosition;
  CameraPosition _initialLocation = CameraPosition(target: LatLng(0.0, 0.0));
  Completer<GoogleMapController> _controller = Completer();
  final Set<Polygon> _polygons = HashSet<Polygon>();
  final Set<Polyline> _polyLines = HashSet<Polyline>();
  Set<Marker> customMarkers = {};
  List<LatLng> userPolyLinesLatLngList = [];
  double area = 0.0;
  String address = '';
  bool _drawPolygonEnabled = false;
  double? height, width;
  var bitmapImage;

  @override
  void initState() {
    // ignore: todo
    // TODO: implement initState
    super.initState();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    // Determining the screen width & height
    height = MediaQuery.of(context).size.height;
    width = MediaQuery.of(context).size.width;
    return Scaffold(
        body: Container(
      width: width,
      height: height,
      child: Stack(
        children: <Widget>[
          GoogleMap(
              initialCameraPosition: _initialLocation,
              myLocationEnabled: true,
              mapType: MapType.hybrid,
              polygons: _polygons,
              polylines: _polyLines,
              markers: customMarkers,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              onTap: (LatLng latLng) => _onTapDown(context, latLng),
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              }),
          Positioned(
            bottom: 30,
            right: 20,
            child: ClipOval(
              child: Material(
                color: Colors.orange[100], // button color
                child: InkWell(
                  splashColor: Colors.orange, // inkwell color
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(Icons.my_location),
                  ),
                  onTap: () {
                    _getCurrentLocation();
                    // on button tap
                  },
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              width: 240,
              height: 100,
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Area : ${area.toStringAsFixed(2)}m2',
                    style: TextStyle(color: Colors.black, fontSize: 20),
                  ),
                  Expanded(
                      child: Text(
                    'Address: $address',
                    style: TextStyle(color: Colors.black, fontSize: 20),
                  ))
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: 20,
            child: ClipOval(
              child: Material(
                color: Colors.blue[100], // button color
                child: InkWell(
                  splashColor: Colors.blue, // inkwell color
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(
                      (_drawPolygonEnabled) ? Icons.cancel : Icons.edit,
                    ),
                  ),
                  onTap: _toggleDrawing,
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }

  _toggleDrawing() {
    _clearPolygons();
    setState(() => _drawPolygonEnabled = !_drawPolygonEnabled);
  }

  _clearPolygons() {
    setState(() {
      area = 0;
      address = "";
      _polyLines.clear();
      _polygons.clear();
      userPolyLinesLatLngList.clear();
      customMarkers.clear();
    });
  }

  Future<void> _createMarkerImageFromAsset(String iconPath) async {
    ImageConfiguration configuration = ImageConfiguration();
    var image = await BitmapDescriptor.fromAssetImage(configuration, iconPath);
    setState(() {
      bitmapImage = image;
    });
  }

  _addMaker(LatLng latLng) {
    if (customMarkers.length == 0) {
      _createMarkerImageFromAsset('images/location.png');
      _getAddress(userPolyLinesLatLngList[0]);
      customMarkers.add(Marker(
        markerId: MarkerId(latLng.toString()),
        position: latLng,
        icon: bitmapImage,
        infoWindow: InfoWindow(
            title: 'Connect to create polygon',
            onTap: () {
              _polygons.add(
                Polygon(
                  polygonId: PolygonId('user_polygon'),
                  points: userPolyLinesLatLngList,
                  strokeWidth: 2,
                  strokeColor: Colors.blue,
                  fillColor: Colors.blue.withOpacity(0.4),
                ),
              );
              setState(() {
                area = _polygonArea(userPolyLinesLatLngList);
              });
            }),
      ));
    } else {
      customMarkers.add(Marker(
        markerId: MarkerId(latLng.toString()),
        position: latLng,
        icon: bitmapImage,
      ));
    }
  }

  _onTapDown(BuildContext context, LatLng latLng) async {
    if (_drawPolygonEnabled) {
      userPolyLinesLatLngList.add(latLng);
      _addMaker(latLng);
      try {
        _polyLines.add(
          Polyline(
            polylineId: PolylineId('user_polyline'),
            points: userPolyLinesLatLngList,
            width: 2,
            color: Colors.blue,
          ),
        );
      } catch (e) {
        print(" error painting $e");
        return;
      }

      setState(() {});
    }
  }

  double _polygonArea(List<LatLng> polygon) {
    List<mt.LatLng> listPoint = [];
    polygon.forEach((e) {
      listPoint.add(mt.LatLng(e.latitude, e.longitude));
    });
    double areaResult = 0.0;
    areaResult = mt.SphericalUtil.computeArea(listPoint) as double;
    return areaResult;
  }

  Future<void> _getAddress(LatLng latLng) async {
    GeoCode geoCode = GeoCode();
    var addresses = await geoCode.reverseGeocoding(
        latitude: latLng.latitude, longitude: latLng.longitude);
    setState(() {
      address = addresses.streetAddress.toString() +
          "," +
          addresses.region.toString() +
          "," +
          addresses.countryName.toString();
      print(address);
    });
  }

  _getCurrentLocation() async {
    final GoogleMapController controller = await _controller.future;
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((Position position) async {
      setState(() {
        // Store the position in the variable
        _currentPosition = position;

        print('CURRENT POS: $_currentPosition');

        // For moving the camera to current location
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 18.0,
            ),
          ),
        );
      });
    }).catchError((e) {
      print(e);
    });
  }
}
