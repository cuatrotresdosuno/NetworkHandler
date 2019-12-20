//
//  NetworkHandler.swift
//
//  Created by Michael Redig on 5/7/19.
//  Copyright © 2019 Michael Redig. All rights reserved.
//
//swiftlint:disable line_length conditional_returns_on_newline cyclomatic_complexity

import Foundation

/**
Errors specific to networking with NetworkHandler. These specific cases are all
accounted for when using the included `UIAlertController` extension to provide a
*/
public enum NetworkError: Error, Equatable {
	/**
	A generic wrapper for when an `Error` doesn't otherwise fall under one of the
	predetermined categories.
	*/
	case otherError(error: Error)
	/**
	Occurs when a request is expecting data back, but either doesn't get any, or
	gets noticably corrupted data. Wraps the source data for debugging.
	*/
	case badData(sourceData: Data?)
	/**
	Occurs when using a `Codable` data type that can't get decoded or encoded. Wraps
	the original error and source data for debugging.
	*/
	case dataCodingError(specifically: Error, sourceData: Data?)
	/**
	Not used within the NetworkHandler framework, but a preset error available for
	use when attempting to decode an image from a remote source and failing.
	Compatible with the UIAlertController extension included.
	*/
	case imageDecodeError
	/**
	Not used within the NetworkHandler framework, but a preset error available for
	use when a URL is invalid. Can wrap the offending `String`. Compatible with the
	UIAlertController extension included.
	*/
	case urlInvalid(urlString: String?)
	/// Thrown when a `URLResponse` doesn't include a valid response code.
	case noStatusCodeResponse
	/**
	Thrown when a `URLResponse` includes a response code other than 200, or a range
	of 200-299 (depending on whether `strict200CodeResponse` is on or off). Wraps
	the response code and included `Data?`, is there is any.
	*/
	case httpNon200StatusCode(code: Int, data: Data?)
	/**
	Not used within the NetworkHandler framework, but a preset error available for
	use when there's an error with whatever database you're using. Wraps the
	original `Error`. Generically labeled to account for other databases, like Realm
	or CoreData. Compatible with the UIAlertController extension included.
	*/
	case databaseFailure(specifically: Error)
	/**
	Some APIs (Firebase) will return a value of `null` when the request yields no
	results. Sometimes this is okay, so in those cases, you can check for if this is
	the case and proceed logically (for example, don't show the user an error and
	instead just show a lack of data shown in the event of an empty list)

	Note that the user presented alert associated with this error is NOT helpful,
	so if this can be reasonably expected at all, you want to try to handle it
	internally.

	```
	do {
		let result = try results.get()
	} catch NetworkError.dataWasNull {
		// oh okay, no results... just empty the model controller array
	} catch {
		// Another error occured, handle it!
	}
	```
	*/
	case dataWasNull
	/**
	If you need to provide an error state but none of the other specified cases
	apply, use this. Optionally provide a reason. Useful for when guard statements fail.
	*/
	case unspecifiedError(reason: String?)
	case graphQLError(error: GQLError)

	public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
		switch lhs {
		case .badData(let lhsSourceData):
			if case .badData(let rhsSourceData) = rhs, lhsSourceData == rhsSourceData { return true } else { return false }
		case .databaseFailure(specifically: let otherError):
			if case .databaseFailure(let rhsError) = rhs, otherError.localizedDescription == rhsError.localizedDescription { return true } else { return false }
		case .dataCodingError(specifically: let otherError, let lhsSourceData):
			if case .dataCodingError(let rhsError, let rhsSourceData) = rhs,
				otherError.localizedDescription == rhsError.localizedDescription,
			lhsSourceData == rhsSourceData { return true } else { return false }
		case .dataWasNull:
			if case .dataWasNull = rhs { return true } else { return false }
		case .httpNon200StatusCode(code: let code, data: let data):
			if case .httpNon200StatusCode(let rhsCode, let rhsData) = rhs, code == rhsCode, data == rhsData { return true } else { return false }
		case .imageDecodeError:
			if case .imageDecodeError = rhs { return true } else { return false }
		case .noStatusCodeResponse:
			if case .noStatusCodeResponse = rhs { return true } else { return false }
		case .otherError(let otherError):
			if case .otherError(let rhsError) = rhs, otherError.localizedDescription == rhsError.localizedDescription { return true } else { return false }
		case .urlInvalid(let urlString):
			if case .urlInvalid(let rhsURLString) = rhs, urlString == rhsURLString { return true } else { return false }
		case .unspecifiedError(let lhsReason):
			if case .unspecifiedError(let rhsReason) = rhs, lhsReason == rhsReason { return true } else { return false }
		case .graphQLError(let lhsError):
			if case .graphQLError(let rhsError) = rhs, lhsError == rhsError { return true } else { return false }
		}
	}
}

public class NetworkHandler {

	// MARK: - Properties
	public var printErrorsToConsole = false
	/**
	The decoder used to decode JSON Codable data. You may edit its settings, just
	be aware that its settings apply to all decoding, not just for a single use.
	*/
	public lazy var netDecoder = {
		JSONDecoder()
	}()

	/// When querying for Codable data, if the response received is `null` (typically in the event that a remote object
	/// doesn't exist - This ocurrs on firebase for example) consider it valid as an empty collection. Only works on
	/// types that conform to Sequence.
	public var nullDataIsValid = false

	/// Set this value to `true` when dealing with a graphQL server as they return a `200` response code even in error
	/// states, but with different (error) json model. Turning this on will then attempt to decode the json error model
	/// and pass forward the errors provided by the graphQL server.
	public var graphQLErrorSupport = false

	/**
	An instance of Network Cache to speed up subsequent requests. Usage is
	optional, but automatic when making requests using the `usingCache` flag.

	Note that URLCache is still used behind the scenes for requests that don't have
	the `usingCache` flag toggled true. This means that you can modify and have the
	current level of support by using the URLRequest's `cachePolicy` property for
	requests that don't have `usingCache` true. However, when `usingCache` is
	toggled true, local and remote cache policy headers are ignored and the data is
	stored indefinitely (until it either gets deleted to make space for more recent
	cache objects or the app is closed), ready to be reloaded instantly the next
	time a duplicate URL request is made (Note that it is unique to the URL, not the
	URLRequest). Additionally, to refrain from duplicating data locally, if data is
	stored in the `NetworkCache`, it is also removed from the `URLCache` if it
	exists.
	*/
	public let cache = NetworkCache()

	/// A default instance of NetworkHandler provided for convenience. Use is optional.
	public static let `default` = NetworkHandler()

	// MARK: - Lifecycle
	/// Initialize a new NetworkHandler instance.
	public init() {}

	// MARK: - Network Handling
	/**
	Preconfigured URLSession tasking to fetch, decode, and provide decodable json data.

	- Parameters:
		- request: NetworkRequest containing the url and other request information.
		- useCache: Bool toggle indicating whether to use cache or not.
		**Default**: `false`
		- session: URLSession instance. **Default**: `URLSession.shared`
		- completion: completion closure run when the data task is finished.
		Provides a `Result` type argument providing `Data?` when there was a
		successful transaction, but a `NetworkError` when failure ocurred.
	- Returns: The resulting, generated `URLSessionDataTask`. In the event that
	you're either mocking or have `usingCache` flagged `true` and there is cached
	data, returns nil.
	*/
	@discardableResult public func transferMahCodableDatas<DecodableType: Decodable>(with request: NetworkRequest, usingCache useCache: Bool = false, session: NetworkLoader = URLSession.shared, completion: @escaping (Result<DecodableType, NetworkError>) -> Void) -> URLSessionDataTask? {

		let task = transferMahDatas(with: request, usingCache: useCache, session: session) { [weak self] result in
			guard let self = self else { return }
			let decoder = self.netDecoder

			var data = Data()
			do {
				data = try result.get()
			} catch {
				completion(.failure(error as? NetworkError ?? NetworkError.otherError(error: error)))
				return
			}

			do {
				let newType = try decoder.decode(DecodableType.self, from: data)
				completion(.success(newType))
			} catch {
				let nullData = "null".data(using: .utf8)!
				if data == nullData {
					completion(.failure(.dataWasNull))
					return
				}
				self.printToConsole("Error decoding data in \(#file) line: \(#line): \(error)")
				completion(.failure(.dataCodingError(specifically: error, sourceData: data)))
			}
		}
		return task
	}

	/**
	Preconfigured URLSession tasking to fetch and provide data.

	- Parameters:
		- request: NetworkRequest containing the url and other request information.
		- useCache: Bool toggle indicating whether to use cache or not.
		**Default**: `false`
		- session: URLSession instance. **Default**: `URLSession.shared`
		- completion: completion closure run when the data task is finished.
		Provides a `Result` type argument providing `Data?` when there was a
		successful transaction, but a `NetworkError` when failure ocurred.
	- Returns: The resulting, generated `URLSessionDataTask`. In the event that
	you're either mocking or have `usingCache` flagged `true` and there is cached
	data, returns nil.
	*/
	@discardableResult public func transferMahDatas(with request: NetworkRequest, usingCache useCache: Bool = false, session: NetworkLoader = URLSession.shared, completion: @escaping (Result<Data, NetworkError>) -> Void) -> URLSessionDataTask? {
		let task = transferMahOptionalDatas(with: request, usingCache: useCache, session: session) { (result: Result<Data?, NetworkError>) in
			do {
				let optData = try result.get()
				guard let data = optData else {
					self.printToConsole("\(String(describing: NetworkError.badData))")
					completion(.failure(.badData(sourceData: optData)))
					return
				}
				completion(.success(data))
			} catch {
				completion(.failure(error as? NetworkError ?? NetworkError.otherError(error: error)))
			}
		}
		return task
	}


	/**
	Preconfigured URLSession tasking to fetch and provide optional data,
	primarily for when you don't actually care about the response.

	- Parameters:
		- request: NetworkRequest containing the url and other request information.
		- useCache: Bool toggle indicating whether to use cache or not.
		**Default**: `false`
		- session: URLSession instance. **Default**: `URLSession.shared`
		- completion: completion closure run when the data task is finished.
		Provides a `Result` type argument providing `Data?` when there was a
		successful transaction, but a `NetworkError` when failure ocurred.
	 - Returns: The resulting, generated `URLSessionDataTask`. In the event that
		you're either mocking or have `usingCache` flagged `true` and there is cached
		data, returns nil.
	*/
	@discardableResult public func transferMahOptionalDatas(with request: NetworkRequest, usingCache useCache: Bool = false, session: NetworkLoader = URLSession.shared, completion: @escaping (Result<Data?, NetworkError>) -> Void) -> URLSessionDataTask? {
		if useCache {
			if let url = request.url, let data = cache[url] {
				completion(.success(data))
				return nil
			}
		}

		let task = session.loadData(with: request.urlRequest) { [weak self] data, response, error in
			guard let self = self else { return }
			if let response = response as? HTTPURLResponse {
				if !request.expectedResponseCodes.contains(response.statusCode) {
					self.printToConsole("Received an unexpected http response: \(response.statusCode) in \(#file) line: \(#line)")
					completion(.failure(.httpNon200StatusCode(code: response.statusCode, data: data)))
					return
				}
			} else {
				self.printToConsole("Did not receive a proper response code in \(#file) line: \(#line)")
				completion(.failure(.noStatusCodeResponse))
				return
			}

			if self.graphQLErrorSupport,
				let data = data,
				let errorContainer = try? JSONDecoder().decode(GQLErrorContainer.self, from: data),
				let error = errorContainer.errors.first {
				completion(.failure(.graphQLError(error: error)))
				return
			}

			if let error = error {
				self.printToConsole("An error was encountered: \(error) in \(#file) line: \(#line)")
				completion(.failure(error as? NetworkError ?? .otherError(error: error)))
				return
			}

			completion(.success(data))
			if useCache, let url = request.url, let data = data {
				// save into cache
				self.cache[url] = data
				// don't duplicate cached data
				URLCache.shared.removeCachedResponse(for: request.urlRequest)
			}
		}
		task?.resume()
		return task
	}

	private func printToConsole(_ string: String) {
		if printErrorsToConsole {
			print(string)
		}
	}
}
