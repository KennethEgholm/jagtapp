import MapLibre
import SwiftUI

/// An explicit ask to fly the map somewhere. Each ask has a new `id`; the map flies once per id.
struct MapCameraRequest: Equatable {
    var id: Int
    var camera: MapCamera
}

/// MapLibre's map with the OpenFreeMap basemap. The map starts at `initialCamera` and
/// moves only when `request` has a new id; a changed `initialCamera` is ignored.
/// `parcels` (GeoJSON) and `saveFrame` draw on top of the basemap.
///
/// `followRequest` and `accuracyRequest` work like `request`: the map acts once per new
/// value. Following the user's position starts only from the button, and a pan ends it.
struct ParcelMapView: UIViewRepresentable {
    var initialCamera: MapCamera
    var request: MapCameraRequest?
    /// Bump to start following the user's position.
    var followRequest = 0
    /// Bump to ask for temporary full accuracy.
    var accuracyRequest = 0
    /// The user allows only approximate location. Tells it from MapLibre's location manager callback.
    var onReducedAccuracy: (Bool) -> Void = { _ in }
    /// The user moved the map with a gesture.
    var onUserMove: () -> Void
    var parcels: Data?
    var saveFrame: GeoBox?
    /// The visible bounds and the zoom, after every move.
    var onRegionChange: (GeoBox, Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: OpenFreeMap.styleURL)
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.automaticallyAdjustsContentInset = false
        map.setCenter(initialCamera.center.clLocation, zoomLevel: initialCamera.zoom, animated: false)
        context.coordinator.handledRequest = request?.id
        context.coordinator.handledFollow = followRequest
        context.coordinator.handledAccuracy = accuracyRequest
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onRegionChange = onRegionChange
        coordinator.onUserMove = onUserMove
        coordinator.onReducedAccuracy = onReducedAccuracy
        if let request, request.id != coordinator.handledRequest {
            coordinator.handledRequest = request.id
            map.setCenter(request.camera.center.clLocation, zoomLevel: request.camera.zoom, animated: true)
        }
        if followRequest != coordinator.handledFollow {
            coordinator.handledFollow = followRequest
            map.userTrackingMode = .follow
        }
        if accuracyRequest != coordinator.handledAccuracy {
            coordinator.handledAccuracy = accuracyRequest
            map.locationManager.requestTemporaryFullAccuracyAuthorization?(withPurposeKey: "Skel")
        }
        coordinator.parcels = parcels
        coordinator.saveFrame = saveFrame
        coordinator.drawIfChanged(on: map)
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MLNMapViewDelegate {
        var handledRequest: Int?
        var handledFollow = 0
        var handledAccuracy = 0
        var onReducedAccuracy: (Bool) -> Void = { _ in }
        var onUserMove: () -> Void = {}
        var onRegionChange: (GeoBox, Double) -> Void = { _, _ in }
        var parcels: Data?
        var saveFrame: GeoBox?
        /// What is on the style now, so an unchanged update does not parse the GeoJSON again.
        private var drawnParcels: Data?
        private var drawnFrame: GeoBox?

        private static let parcelsID = "matrikel"
        private static let frameID = "saveFrame"
        /// A font the liberty style's glyph server has.
        private static let labelFont = "Noto Sans Regular"

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            draw(on: mapView)
            reportRegion(of: mapView)
        }

        /// Read from MapLibre's callback, never polled (CoreLocation's main-thread rule).
        func mapView(_ mapView: MLNMapView, didChangeLocationManagerAuthorization manager: MLNLocationManager) {
            onReducedAccuracy(manager.accuracyAuthorization?() == .reducedAccuracy)
        }

        func mapView(_ mapView: MLNMapView, regionWillChangeWith reason: MLNCameraChangeReason, animated: Bool) {
            // Anything but a call from the app is the user: a gesture or the compass.
            if !reason.subtracting(.programmatic).isEmpty { onUserMove() }
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeWith reason: MLNCameraChangeReason, animated: Bool) {
            reportRegion(of: mapView)
        }

        private func reportRegion(of mapView: MLNMapView) {
            let bounds = mapView.visibleCoordinateBounds
            onRegionChange(
                GeoBox(south: bounds.sw.latitude, west: bounds.sw.longitude, north: bounds.ne.latitude, east: bounds.ne.longitude),
                mapView.zoomLevel
            )
        }

        func drawIfChanged(on map: MLNMapView) {
            guard parcels != drawnParcels || saveFrame != drawnFrame else { return }
            draw(on: map)
        }

        /// Puts the parcels and the save frame on the style, or takes them off.
        func draw(on map: MLNMapView) {
            guard let style = map.style else { return }
            drawnParcels = parcels
            drawnFrame = saveFrame
            drawParcels(on: style)
            let frameShape = saveFrame.map { box -> MLNShape in
                var corners = [
                    CLLocationCoordinate2D(latitude: box.south, longitude: box.west),
                    CLLocationCoordinate2D(latitude: box.south, longitude: box.east),
                    CLLocationCoordinate2D(latitude: box.north, longitude: box.east),
                    CLLocationCoordinate2D(latitude: box.north, longitude: box.west),
                    CLLocationCoordinate2D(latitude: box.south, longitude: box.west),
                ]
                return MLNPolylineFeature(coordinates: &corners, count: UInt(corners.count))
            }
            setFrame(frameShape, style: style)
        }

        /// The source `matrikel` with a white casing, the red boundary and the matrikelnumre.
        /// The source stays when there is nothing to draw, just empty, so the layers do not flicker.
        private func drawParcels(on style: MLNStyle) {
            let shape = parcels.flatMap { try? MLNShape(data: $0, encoding: String.Encoding.utf8.rawValue) }
                ?? MLNShapeCollectionFeature(shapes: [])
            if let source = style.source(withIdentifier: Self.parcelsID) as? MLNShapeSource {
                source.shape = shape
                return
            }
            let source = MLNShapeSource(identifier: Self.parcelsID, shape: shape, options: nil)
            style.addSource(source)

            func widths(_ low: Double, _ high: Double) -> NSExpression {
                NSExpression(
                    forMLNInterpolating: .zoomLevelVariable,
                    curveType: .linear,
                    parameters: nil,
                    stops: NSExpression(forConstantValue: [MapRules.boundaryMinZoom: low, 18: high])
                )
            }

            let casing = MLNLineStyleLayer(identifier: "matrikel-casing", source: source)
            casing.minimumZoomLevel = Float(MapRules.boundaryMinZoom)
            casing.lineColor = NSExpression(forConstantValue: UIColor.white)
            casing.lineOpacity = NSExpression(forConstantValue: 0.6)
            casing.lineWidth = widths(2, 4.5)
            casing.lineJoin = NSExpression(forConstantValue: "round")
            style.addLayer(casing)

            let line = MLNLineStyleLayer(identifier: "matrikel-line", source: source)
            line.minimumZoomLevel = Float(MapRules.boundaryMinZoom)
            line.lineColor = NSExpression(forConstantValue: UIColor.boundary)
            line.lineWidth = widths(1, 2.5)
            line.lineJoin = NSExpression(forConstantValue: "round")
            style.addLayer(line)

            let labels = MLNSymbolStyleLayer(identifier: "matrikel-nr", source: source)
            labels.minimumZoomLevel = Float(MapRules.labelMinZoom)
            labels.text = NSExpression(forKeyPath: "nr")
            labels.textFontNames = NSExpression(forConstantValue: [Self.labelFont])
            labels.textFontSize = NSExpression(
                forMLNInterpolating: .zoomLevelVariable,
                curveType: .linear,
                parameters: nil,
                stops: NSExpression(forConstantValue: [MapRules.labelMinZoom: 11, 19: 14])
            )
            labels.textColor = NSExpression(forConstantValue: UIColor.boundary)
            labels.textHaloColor = NSExpression(forConstantValue: UIColor.white)
            labels.textHaloWidth = NSExpression(forConstantValue: 1.5)
            style.addLayer(labels)
        }

        private func setFrame(_ shape: MLNShape?, style: MLNStyle) {
            if let source = style.source(withIdentifier: Self.frameID) as? MLNShapeSource {
                if let shape {
                    source.shape = shape
                } else {
                    if let layer = style.layer(withIdentifier: Self.frameID) { style.removeLayer(layer) }
                    style.removeSource(source)
                }
                return
            }
            guard let shape else { return }
            let source = MLNShapeSource(identifier: Self.frameID, shape: shape, options: nil)
            style.addSource(source)
            let layer = MLNLineStyleLayer(identifier: Self.frameID, source: source)
            layer.lineColor = NSExpression(forConstantValue: UIColor.label)
            layer.lineWidth = NSExpression(forConstantValue: 2)
            style.addLayer(layer)
        }
    }
}

private extension Coordinate {
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
