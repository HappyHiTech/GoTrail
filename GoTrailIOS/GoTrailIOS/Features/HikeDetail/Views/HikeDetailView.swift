import Foundation
import SwiftUI
import MapKit
#if canImport(UIKit)
import UIKit
#endif

struct HikeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: HikeDetailViewModel

    private let green = Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255)
    private let pageBackground = Color(red: 245 / 255, green: 248 / 255, blue: 245 / 255)

    init(hikeId: UUID) {
        _viewModel = StateObject(wrappedValue: HikeDetailViewModel(hikeId: hikeId))
    }

    var body: some View {
        GeometryReader { geometry in
            let topInset = geometry.safeAreaInsets.top
            let horizontalPadding = max(16, geometry.size.width * 0.05)
            let heroHeight = min(max(250, geometry.size.height * 0.42), 360)

            ZStack(alignment: .top) {
                pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection(topInset: topInset, heroHeight: heroHeight, horizontalPadding: horizontalPadding)
                        detailsSection(horizontalPadding: horizontalPadding)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.load()
        }
    }

    private func heroSection(topInset: CGFloat, heroHeight: CGFloat, horizontalPadding: CGFloat) -> some View {
        ZStack(alignment: .top) {
            RoutePreviewMap(
                routepoints: viewModel.routepoints,
                pictures: viewModel.sortedPictures,
                selectedPictureID: viewModel.selectedPicture?.id,
                onPinTap: { pictureID in
                    viewModel.selectPicture(pictureID)
                }
            )
            .frame(height: heroHeight)
            .overlay(alignment: .bottom) {
                if viewModel.sortedPictures.isEmpty == false {
                    hintPill
                        .padding(.bottom, 12)
                }
            }

            HStack(spacing: 10) {
                glassButton(icon: "chevron.left", action: { dismiss() })

                titlePill

                Spacer(minLength: 0)
            }
            .padding(.top, max(0, topInset - 8))
            .padding(.horizontal, horizontalPadding)
        }
    }

    private func detailsSection(horizontalPadding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.isLoading {
                ProgressView()
                    .tint(green)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 94 / 255, green: 94 / 255, blue: 94 / 255))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            } else {
                hikeSummaryCard
                    .padding(.top, 14)

                discoveredSpeciesSection
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, 24)
    }

    private var hikeSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Hike Summary")
                    .font(.custom("Montserrat-Bold", size: 15))
                    .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))

                Spacer()

                Text("Completed")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255))
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Color.black.opacity(0.06))
                    .clipShape(Capsule())
            }

            Divider()
                .overlay(Color(red: 235 / 255, green: 235 / 255, blue: 235 / 255))

            HStack(spacing: 0) {
                summaryStatBlock(icon: "mappin", title: "Location", value: viewModel.locationText, subtitle: "Recorded location")
                Rectangle().fill(Color(red: 235 / 255, green: 235 / 255, blue: 235 / 255)).frame(width: 1)
                summaryStatBlock(icon: "calendar", title: "Date", value: viewModel.dateText, subtitle: "Hike date")
            }
            .frame(height: 78)

            Divider()
                .overlay(Color(red: 235 / 255, green: 235 / 255, blue: 235 / 255))

            HStack(spacing: 0) {
                summaryStatBlock(icon: "clock", title: "Duration", value: viewModel.durationText, subtitle: "Elapsed")
                Rectangle().fill(Color(red: 235 / 255, green: 235 / 255, blue: 235 / 255)).frame(width: 1)
                summaryStatBlock(icon: "paperclip", title: "Distance", value: viewModel.distanceText, subtitle: "Total trail")
            }
            .frame(height: 78)
        }
        .padding(16)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }

    private func summaryStatBlock(icon: String, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
            }

            Text(value)
                .font(.custom("Montserrat-Bold", size: 16))
                .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private var discoveredSpeciesSection: some View {
        let speciesPictures = viewModel.sortedPictures
            .filter { ($0.species?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "leaf")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                    Text("Discovered Species")
                        .font(.custom("Montserrat-Bold", size: 14))
                        .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                }
                Spacer()
                Text("\(speciesPictures.count) found")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 22)
                    .background(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                    .clipShape(Capsule())
            }

            if speciesPictures.isEmpty {
                Text("No identified species found for this hike yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 94 / 255, green: 94 / 255, blue: 94 / 255))
                    .padding(.vertical, 6)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ]

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(speciesPictures) { picture in
                        speciesCard(for: picture)
                    }
                }
            }
        }
    }

    private func speciesCard(for picture: Picture) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let imageURL = viewModel.resolvedURL(for: picture) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholderPhoto
                    }
                }
            } else {
                placeholderPhoto
            }
        }
        .frame(height: 174)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Text("Photo")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(Color.black.opacity(0.68))
                .clipShape(Capsule())
                .padding(6)
        }
        .overlay(alignment: .bottomLeading) {
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(picture.species ?? "Unknown species")
                            .font(.custom("Montserrat-Bold", size: 15))
                            .foregroundStyle(.white)
                        Text(picture.speciesInfo ?? "Trail observation")
                            .font(.system(size: 10, weight: .medium))
                            .italic()
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }
                    .padding(8)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    private var placeholderPhoto: some View {
        LinearGradient(
            colors: [
                Color(red: 240 / 255, green: 245 / 255, blue: 240 / 255),
                Color(red: 226 / 255, green: 234 / 255, blue: 226 / 255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(green.opacity(0.6))
                Text("Photo unavailable")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(green.opacity(0.7))
            }
        }
    }

    private var titlePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.circle")
                .font(.system(size: 11, weight: .semibold))
            Text(viewModel.titleText)
                .font(.custom("Montserrat-Bold", size: 12))
                .lineLimit(1)
        }
        .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(.white.opacity(0.92))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }

    private var hintPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "camera")
                .font(.system(size: 9, weight: .semibold))
            Text("Tap a pin to preview a photo")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(.white.opacity(0.88))
        .clipShape(Capsule())
    }

    private func glassButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.9))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.14), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private struct RoutePreviewMap: UIViewRepresentable {
    let routepoints: [Routepoint]
    let pictures: [Picture]
    let selectedPictureID: UUID?
    let onPinTap: (UUID) -> Void

    private let green = UIColor(red: 30 / 255, green: 86 / 255, blue: 49 / 255, alpha: 1)

    func makeCoordinator() -> Coordinator {
        Coordinator(onPinTap: onPinTap)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsTraffic = false
        mapView.showsBuildings = false
        mapView.mapType = .mutedStandard
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.green = green
        context.coordinator.selectedPictureID = selectedPictureID

        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

        let routeCoordinates = routepoints.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let pinAnnotations = pictures.compactMap { picture -> PictureAnnotation? in
            guard let latitude = picture.latitude, let longitude = picture.longitude else { return nil }
            let annotation = PictureAnnotation(
                pictureID: picture.id,
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            )
            annotation.title = picture.species ?? "Plant"
            return annotation
        }

        if routeCoordinates.count > 1 {
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            mapView.addOverlay(polyline)
        }

        mapView.addAnnotations(pinAnnotations)

        if let selectedPictureID {
            if let selected = pinAnnotations.first(where: { $0.pictureID == selectedPictureID }) {
                mapView.selectAnnotation(selected, animated: false)
            }
        }

        let datasetKey = makeDatasetKey(routeCoordinates: routeCoordinates, pinAnnotations: pinAnnotations)
        if context.coordinator.lastDatasetKey != datasetKey {
            context.coordinator.lastDatasetKey = datasetKey
            fitVisibleRect(
                mapView: mapView,
                routeCoordinates: routeCoordinates,
                pinAnnotations: pinAnnotations
            )
        }
    }

    private func makeDatasetKey(routeCoordinates: [CLLocationCoordinate2D], pinAnnotations: [PictureAnnotation]) -> String {
        let firstRoute = routeCoordinates.first
        let lastRoute = routeCoordinates.last
        let firstPin = pinAnnotations.first?.coordinate
        let lastPin = pinAnnotations.last?.coordinate
        return [
            "r:\(routeCoordinates.count)",
            "p:\(pinAnnotations.count)",
            "rf:\(firstRoute?.latitude ?? 0),\(firstRoute?.longitude ?? 0)",
            "rl:\(lastRoute?.latitude ?? 0),\(lastRoute?.longitude ?? 0)",
            "pf:\(firstPin?.latitude ?? 0),\(firstPin?.longitude ?? 0)",
            "pl:\(lastPin?.latitude ?? 0),\(lastPin?.longitude ?? 0)"
        ].joined(separator: "|")
    }

    private func fitVisibleRect(
        mapView: MKMapView,
        routeCoordinates: [CLLocationCoordinate2D],
        pinAnnotations: [PictureAnnotation]
    ) {
        var rect = MKMapRect.null

        for coordinate in routeCoordinates {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
            rect = rect.isNull ? pointRect : rect.union(pointRect)
        }

        for annotation in pinAnnotations {
            let point = MKMapPoint(annotation.coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
            rect = rect.isNull ? pointRect : rect.union(pointRect)
        }

        if rect.isNull {
            let fallback = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 34.0113, longitude: -116.1669),
                span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
            )
            mapView.setRegion(fallback, animated: false)
            return
        }

        mapView.setVisibleMapRect(
            rect,
            edgePadding: UIEdgeInsets(top: 48, left: 28, bottom: 48, right: 28),
            animated: false
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let onPinTap: (UUID) -> Void
        var green: UIColor = .systemGreen
        var selectedPictureID: UUID?
        var lastDatasetKey: String?

        init(onPinTap: @escaping (UUID) -> Void) {
            self.onPinTap = onPinTap
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = green
            renderer.lineWidth = 4
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pictureAnnotation = annotation as? PictureAnnotation else { return nil }

            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: PictureAnnotationView.reuseIdentifier
            ) as? PictureAnnotationView ?? PictureAnnotationView(
                annotation: pictureAnnotation,
                reuseIdentifier: PictureAnnotationView.reuseIdentifier
            )

            view.configure(
                isSelected: pictureAnnotation.pictureID == selectedPictureID,
                tintColor: green
            )
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let pictureAnnotation = view.annotation as? PictureAnnotation else { return }
            onPinTap(pictureAnnotation.pictureID)
        }
    }
}

private final class PictureAnnotation: NSObject, MKAnnotation {
    let pictureID: UUID
    let coordinate: CLLocationCoordinate2D
    var title: String?

    init(pictureID: UUID, coordinate: CLLocationCoordinate2D) {
        self.pictureID = pictureID
        self.coordinate = coordinate
    }
}

private final class PictureAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "PictureAnnotationView"

    private let iconImageView = UIImageView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        layer.borderWidth = 0
    }

    func configure(isSelected: Bool, tintColor: UIColor) {
        backgroundColor = isSelected ? tintColor : .white
        iconImageView.tintColor = isSelected ? .white : tintColor
        layer.borderColor = tintColor.cgColor
        layer.borderWidth = 1.5
        layer.cornerRadius = bounds.width / 2
    }

    private func setupView() {
        frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        canShowCallout = false
        centerOffset = CGPoint(x: 0, y: -1)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 2
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.masksToBounds = false

        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        iconImageView.image = UIImage(systemName: "camera", withConfiguration: config)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

#Preview {
    HikeDetailView(hikeId: UUID())
}
