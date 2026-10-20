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
struct ParcelMapView: UIViewRepresentable {
    var initialCamera: MapCamera
    var request: MapCameraRequest?
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
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onRegionChange = onRegionChange
        coordinator.onUserMove = onUserMove
        if let request, request.id != coordinator.handledRequest {
            coordinator.handledRequest = request.id
            map.setCenter(request.camera.center.clLocation, zoomLevel: request.camera.zoom, animated: true)
        }
        coordinator.parcels = parcels
        coordinator.saveFrame = saveFrame
        coordinator.drawIfChanged(on: map)
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MLNMapViewDelegate {
        var handledRequest: Int?
        var onUserMove: () -> Void = {}
        var onRegionChange: (GeoBox, Double) -> Void = { _, _ in }
        var parcels: Data?
        var saveFrame: GeoBox?
        /// What is on the style now, so an unchanged update does not parse the GeoJSON again.
        private var drawnParcels: Data?
        private var drawnFrame: GeoBox?

        private static let parcelsID = "parcels"
        private static let frameID = "saveFrame"

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            draw(on: mapView)
        }

        func mapView(_ mapView: MLNMapView, regionWillChangeWith reason: MLNCameraChangeReason, animated: Bool) {
            // Anything but a call from the app is the user: a gesture or the compass.
            if !reason.subtracting(.programmatic).isEmpty { onUserMove() }
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeWith reason: MLNCameraChangeReason, animated: Bool) {
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
            let tint = UIColor(named: "Brass") ?? .systemOrange
            let parcelShape = parcels.flatMap { try? MLNShape(data: $0, encoding: String.Encoding.utf8.rawValue) }
            setShape(parcelShape, id: Self.parcelsID, style: style, width: 1.5, color: tint)
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
            setShape(frameShape, id: Self.frameID, style: style, width: 2, color: .label)
        }

        private func setShape(_ shape: MLNShape?, id: String, style: MLNStyle, width: Double, color: UIColor) {
            if let source = style.source(withIdentifier: id) as? MLNShapeSource {
                if let shape {
                    source.shape = shape
                } else {
                    if let layer = style.layer(withIdentifier: id) { style.removeLayer(layer) }
                    style.removeSource(source)
                }
                return
            }
            guard let shape else { return }
            let source = MLNShapeSource(identifier: id, shape: shape, options: nil)
            style.addSource(source)
            let layer = MLNLineStyleLayer(identifier: id, source: source)
            layer.lineColor = NSExpression(forConstantValue: color)
            layer.lineWidth = NSExpression(forConstantValue: width)
            style.addLayer(layer)
        }
    }
}

private extension Coordinate {
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
