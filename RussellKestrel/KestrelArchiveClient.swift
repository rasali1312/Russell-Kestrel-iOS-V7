import Foundation

final class KestrelArchiveClient {
    private let session: URLSession
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        session = URLSession(configuration: configuration)
    }
    func loadArchivePage(_ url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        session.dataTask(with: url) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data else {
                completion(.failure(URLError(.badServerResponse))); return
            }
            completion(.success(data))
        }.resume()
    }
}
