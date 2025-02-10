import SwiftUI
import Network

class ImageViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var savedImages: [ImageFile] = []
    
    private var networkMonitor = NetworkMonitor()  // ✅ 네트워크 감지
    
    init() {
        createICloudFolderIfNeeded()
        loadImagesFromICloud()
        
        // ✅ 네트워크가 연결될 때 로컬 파일 iCloud로 업로드
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            if self.networkMonitor.isConnected {
                self.uploadLocalFilesToICloud()
            }
        }
    }
    
    /// 📌 iCloud Drive 저장 경로 가져오기
    private func getICloudDirectory() -> URL? {
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }
    
    /// 📌 로컬 저장 경로 가져오기 (오프라인 저장용)
    private func getLocalDirectory() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// 📌 iCloud Drive에 `Documents` 폴더가 없으면 생성
    private func createICloudFolderIfNeeded() {
        guard let iCloudURL = getICloudDirectory() else {
            print("❌ iCloud Drive 접근 불가")
            return
        }
        
        print("📂 iCloud Drive 예상 경로: \(iCloudURL.path)") // 📌 폴더 경로 확인
        
        if !FileManager.default.fileExists(atPath: iCloudURL.path) {
            do {
                try FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true, attributes: nil)
                print("✅ iCloud Drive 폴더 생성됨: \(iCloudURL.path)")
            } catch {
                print("❌ iCloud Drive 폴더 생성 실패: \(error.localizedDescription)")
            }
        } else {
            print("✅ iCloud Drive 폴더가 이미 존재함: \(iCloudURL.path)")
        }
        
        forceICloudSync()
    }
    
    /// 📌 iCloud 또는 로컬에 이미지 저장 (자동 선택)
    func saveImage(image: UIImage) {
        let fileName = "image_\(UUID().uuidString).jpg"
        
        if networkMonitor.isConnected && getICloudDirectory() != nil {
            // 네트워크 연결되어 있고 iCloud 사용 가능할 때
            saveImageToICloud(image: image, fileName: fileName)
            print("✅ 네트워크 연결됨: iCloud에 저장")
        } else {
            // 네트워크 연결 안되어 있거나 iCloud 사용 불가능할 때
            saveImageLocally(image: image, fileName: fileName)
            print("📱 오프라인 모드: 로컬에 저장")
        }
    }
    
    func saveImageToICloud(image: UIImage, fileName: String) {
        guard let data = image.jpegData(compressionQuality: 1.0),
              let iCloudURL = getICloudDirectory()?.appendingPathComponent(fileName),
              let tempURL = getLocalDirectory()?.appendingPathComponent(fileName) else {
            print("❌ iCloud Drive 접근 불가")
            return
        }
        
        do {
            // 📌 1️⃣ 먼저 로컬에 저장
            try data.write(to: tempURL)
            
            // 📌 2️⃣ iCloud로 이동 (이미 존재하면 덮어쓰기)
            if FileManager.default.fileExists(atPath: iCloudURL.path) {
                try FileManager.default.replaceItemAt(iCloudURL, withItemAt: tempURL)
            } else {
                try FileManager.default.copyItem(at: tempURL, to: iCloudURL)
            }
            
            print("✅ iCloud Drive에 저장됨: \(iCloudURL.path)")
            
            // 📌 3️⃣ 파일 보호 속성 해제 (파일 접근 가능하도록 설정)
            try (iCloudURL as NSURL).setResourceValue(URLFileProtection.none, forKey: .fileProtectionKey)
            try (iCloudURL as NSURL).setResourceValue(false, forKey: .isHiddenKey) // 숨김 해제
            
            DispatchQueue.main.async {
                self.loadImagesFromICloud() // ✅ 저장 후 자동으로 목록 새로고침
            }
        } catch {
            print("❌ iCloud 저장 실패: \(error.localizedDescription)")
        }
    }
    
    /// 📌 로컬에 이미지 저장 (오프라인 대비)
    func saveImageLocally(image: UIImage, fileName: String) {
        guard let localURL = getLocalDirectory()?.appendingPathComponent(fileName),
              let data = image.jpegData(compressionQuality: 1.0) else { return }
        
        do {
            try data.write(to: localURL)
            
            // 파일 앱에서 접근 가능하도록 설정
            try (localURL as NSURL).setResourceValue(URLFileProtection.none, forKey: .fileProtectionKey)
            try (localURL as NSURL).setResourceValue(false, forKey: .isExcludedFromBackupKey)
            
            print("✅ 로컬에 저장됨: \(localURL.path)")
            
            DispatchQueue.main.async {
                self.loadImagesFromICloud() // 로컬 이미지도 목록에 표시
            }
        } catch {
            print("❌ 로컬 저장 오류: \(error.localizedDescription)")
        }
    }
    
    /// 📌 네트워크 연결 시 로컬 파일을 iCloud로 업로드
    func uploadLocalFilesToICloud() {
        guard let localDirectory = getLocalDirectory(),
              let iCloudDirectory = getICloudDirectory() else {
            print("❌ 로컬 또는 iCloud 경로 접근 불가")
            return
        }
        
        do {
            let localFiles = try FileManager.default.contentsOfDirectory(at: localDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in localFiles {
                let destinationURL = iCloudDirectory.appendingPathComponent(fileURL.lastPathComponent)
                if !FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                    print("✅ iCloud로 업로드됨: \(fileURL.lastPathComponent)")
                    try FileManager.default.removeItem(at: fileURL) // ✅ 업로드 후 로컬에서 삭제
                }
            }
        } catch {
            print("❌ iCloud 업로드 실패: \(error.localizedDescription)")
        }
    }
    
    /// 📌 iCloud Drive에서 이미지 불러오기
    func loadImagesFromICloud() {
        // iCloud 이미지 로드
        if let iCloudURL = getICloudDirectory() {
            do {
                let iCloudFiles = try FileManager.default.contentsOfDirectory(at: iCloudURL, includingPropertiesForKeys: nil)
                let iCloudImages = iCloudFiles.map { url in
                    ImageFile(fileName: url.lastPathComponent, filePath: url, createdAt: Date())
                }
                
                // 로컬 이미지 로드
                if let localURL = getLocalDirectory() {
                    let localFiles = try FileManager.default.contentsOfDirectory(at: localURL, includingPropertiesForKeys: nil)
                    let localImages = localFiles.map { url in
                        ImageFile(fileName: url.lastPathComponent, filePath: url, createdAt: Date())
                    }
                    
                    // iCloud와 로컬 이미지 합치기
                    DispatchQueue.main.async {
                        self.savedImages = Array(iCloudImages + localImages)
                    }
                }
            } catch {
                print("❌ 이미지 목록 로드 실패: \(error.localizedDescription)")
            }
        }
    }
    
    /// 📌 iCloud Drive에서 특정 파일 삭제
    func deleteFileFromICloud(fileName: String) {
        guard let iCloudURL = getICloudDirectory() else {
            print("❌ iCloud Drive 접근 불가")
            return
        }
        
        let fileURL = iCloudURL.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑 ✅ 파일 삭제 성공: \(fileURL.path)")
                
                DispatchQueue.main.async {
                    self.loadImagesFromICloud() // ✅ 삭제 후 자동으로 목록 새로고침
                }
            } else {
                print("⚠️ 삭제하려는 파일이 존재하지 않음: \(fileURL.path)")
            }
        } catch {
            print("❌ 파일 삭제 실패: \(error.localizedDescription)")
        }
    }
    
    /// 📌 저장된 이미지 불러오기
    func loadImage(from filePath: URL) -> UIImage? {
        if let data = try? Data(contentsOf: filePath) {
            return UIImage(data: data)
        }
        return nil
    }
    
    private func forceICloudSync() {
        let metadataQuery = NSMetadataQuery()
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        
        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery,
            queue: OperationQueue.main
        ) { _ in
            metadataQuery.disableUpdates()
            print("✅ iCloud 강제 동기화 완료")
            metadataQuery.stop()
        }
        
        metadataQuery.start()
    }
    
}


