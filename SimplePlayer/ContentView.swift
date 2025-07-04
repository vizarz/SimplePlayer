import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct Track: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let title: String
    let artist: String
    let artwork: UIImage?
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.url == rhs.url
    }
}

// Менеджер состояния плеера
class PlayerManager: ObservableObject {
    @Published var currentTrack: Track? = nil
    @Published var isFullScreen: Bool = false
}

struct ContentView: View {
    @StateObject private var playerManager = PlayerManager()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                MusicLibraryView(playerManager: playerManager)
                    .tabItem {
                        Image(systemName: "music.note.list")
                        Text("Медиатека")
                    }
                MusicSearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Поиск")
                    }
            }
            
            // Мини-плеер или полноэкранный плеер поверх TabView
            if let track = playerManager.currentTrack {
                if playerManager.isFullScreen {
                    MusicPlayerView(track: track, playerManager: playerManager)
                        .transition(.move(edge: .bottom))
                } else {
                    MiniPlayerView(playerManager: playerManager)
                        .transition(.move(edge: .bottom))
                        .padding(.bottom, 49) // Отступ от TabBar
                }
            }
        }
    }
}

// Мини-плеер поверх TabView
struct MiniPlayerView: View {
    @ObservedObject var playerManager: PlayerManager
    @ObservedObject private var audioManager = AudioPlayerManager.shared
    
    var body: some View {
        if let track = playerManager.currentTrack {
            HStack {
                // Обложка
                if let artwork = track.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    Image(systemName: "music.note")
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .foregroundColor(.gray)
                        .background(Color(.systemGray4))
                        .cornerRadius(8)
                }
                
                // Название и артист
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    Text(track.artist)
                        .font(.system(size: 14))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Кнопка play/pause
                Button(action: {
                    if audioManager.isPlaying {
                        audioManager.pause()
                    } else {
                        audioManager.resume()
                    }
                }) {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            )
            .padding(.horizontal, 16)
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    playerManager.isFullScreen = true
                }
            }
        }
    }
}

struct MusicLibraryView: View {
    @ObservedObject var playerManager: PlayerManager
    @State private var tracks: [Track] = []
    @State private var showImporter = false
    
    var body: some View {
        NavigationView {
            List {
                if tracks.isEmpty {
                    Text("Здесь появится музыка, которую вы импортировали из приложения файлы (для импорта нажмите +)")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 32)
                } else {
                    ForEach(tracks) { track in
                        Button(action: {
                            // Запускаем трек и открываем полноэкранный плеер
                            playerManager.currentTrack = track
                            playerManager.isFullScreen = true
                        }) {
                            HStack {
                                if let artwork = track.artwork {
                                    Image(uiImage: artwork)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 48, height: 48)
                                        .cornerRadius(6)
                                        .clipped()
                                } else {
                                    Image(systemName: "music.note")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                        .foregroundColor(.accentColor)
                                }
                                VStack(alignment: .leading) {
                                    Text(track.title)
                                        .font(.headline)
                                    Text(track.artist)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .onDelete(perform: deleteTrack)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Медиатека")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button(action: {
                showImporter = true
            }) {
                Image(systemName: "plus")
                    .font(.title)
            })
            .sheet(isPresented: $showImporter) {
                DocumentPicker { urls in
                    importTracks(from: urls)
                }
            }
        }
        .onAppear {
            loadTracks()
        }
    }
    
    func importTracks(from urls: [URL]) {
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        for url in urls {
            let fileName = url.lastPathComponent
            let destURL = docsURL.appendingPathComponent(fileName)
            
            if !fileManager.fileExists(atPath: destURL.path) {
                do {
                    try fileManager.copyItem(at: url, to: destURL)
                } catch {
                    print("Ошибка копирования файла: \(error)")
                    continue
                }
            }
            
            let asset = AVAsset(url: destURL)
            var title = destURL.lastPathComponent
            var artist = ""
            var artwork: UIImage? = nil
            
            for meta in asset.commonMetadata {
                if meta.commonKey?.rawValue == "title", let value = meta.value as? String {
                    title = value
                }
                if meta.commonKey?.rawValue == "artist", let value = meta.value as? String {
                    artist = value
                }
                if meta.commonKey?.rawValue == "artwork", let data = meta.value as? Data, let img = UIImage(data: data) {
                    artwork = img
                }
            }
            
            let newTrack = Track(url: destURL, title: title, artist: artist, artwork: artwork)
            if !tracks.contains(newTrack) {
                tracks.append(newTrack)
            }
        }
        saveTracks()
    }
    
    func deleteTrack(at offsets: IndexSet) {
        tracks.remove(atOffsets: offsets)
        saveTracks()
    }

    let tracksKey = "savedTracks"
    
    func saveTracks() {
        let encoder = JSONEncoder()
        let codableTracks = tracks.map {
            CodableTrack(url: $0.url.path, title: $0.title, artist: $0.artist)
        }
        if let data = try? encoder.encode(codableTracks) {
            UserDefaults.standard.set(data, forKey: tracksKey)
        }
    }
    
    func loadTracks() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: tracksKey),
           let codableTracks = try? decoder.decode([CodableTrack].self, from: data) {
            tracks = codableTracks.compactMap { codable in
                let url = URL(fileURLWithPath: codable.url)
                let asset = AVAsset(url: url)
                var artwork: UIImage? = nil
                
                for meta in asset.commonMetadata {
                    if meta.commonKey?.rawValue == "artwork", let data = meta.value as? Data, let img = UIImage(data: data) {
                        artwork = img
                    }
                }
                return Track(url: url, title: codable.title, artist: codable.artist, artwork: artwork)
            }
        }
    }
    
    struct CodableTrack: Codable {
        let url: String
        let title: String
        let artist: String
    }
}

struct MusicPlayerView: View {
    let track: Track
    @ObservedObject var playerManager: PlayerManager
    @ObservedObject private var audioManager = AudioPlayerManager.shared
    @State private var isSeeking = false
    @State private var seekTime: Double = 0

    var body: some View {
        ZStack {
            Color(.systemGray5).ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Капсула для свайпа вниз (убираем кнопку X)
                Capsule()
                    .frame(width: 40, height: 5)
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.top, 16)
                
                Spacer()
                
                // Обложка
                if let artwork = track.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 240, height: 240)
                        .cornerRadius(20)
                } else {
                    Image(systemName: "music.note")
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 240, height: 240)
                        .foregroundColor(.gray)
                        .background(Color(.systemGray4))
                        .cornerRadius(20)
                }
                
                // Название и артист
                VStack(spacing: 4) {
                    Text(track.title)
                        .font(.title2).bold()
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal)
                
                // Полоса перемотки и время
                VStack {
                    Slider(
                        value: Binding(
                            get: {
                                isSeeking ? seekTime : audioManager.currentTime
                            },
                            set: { newValue in
                                isSeeking = true
                                seekTime = newValue
                            }
                        ),
                        in: 0...(audioManager.duration > 0 ? audioManager.duration : 1),
                        onEditingChanged: { editing in
                            if !editing {
                                audioManager.seek(to: seekTime)
                                isSeeking = false
                            }
                        }
                    )
                    
                    HStack {
                        Text(formatTime(isSeeking ? seekTime : audioManager.currentTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(audioManager.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Кнопки управления
                HStack(spacing: 48) {
                    Button(action: {}) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: {
                        togglePlayPause()
                    }) {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                    }
                }
                
                // Громкость
                HStack {
                    Image(systemName: "speaker.fill")
                    Slider(value: .constant(0.5), in: 0...1)
                    Image(systemName: "speaker.wave.3.fill")
                }
                .padding(.horizontal)
                
                // AirPlay и очередь
                HStack {
                    Button(action: {}) {
                        VStack {
                            Image(systemName: "airplayaudio")
                            Text("AirPlay")
                                .font(.caption)
                        }
                    }
                    Spacer()
                    Button(action: {}) {
                        VStack {
                            Image(systemName: "list.bullet")
                            Text("Очередь")
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .onAppear {
            audioManager.play(url: track.url, title: track.title, artist: track.artist, artwork: track.artwork)
        }
        .gesture(
            // Свайп вниз для сворачивания плеера
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            playerManager.isFullScreen = false
                        }
                    }
                }
        )
    }

    func togglePlayPause() {
        if audioManager.isPlaying {
            audioManager.pause()
        } else {
            audioManager.resume()
        }
    }

    func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct MusicSearchView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Поиск...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                Spacer()
            }
            .navigationTitle("Поиск")
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    var completion: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [
            UTType.mp3,
            UTType.mpeg4Audio,
            UTType.audio,
            UTType.aiff,
            UTType.wav
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: ([URL]) -> Void
        
        init(completion: @escaping ([URL]) -> Void) {
            self.completion = completion
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            completion(urls)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
