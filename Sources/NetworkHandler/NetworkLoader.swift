//
//  NetworkLoader
//  NetworkHandler
//
//  Created by Michael Redig on 6/17/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

/// Provides an abstracted method to create a url network request to make testing easier.
public protocol NetworkLoader {
	func loadData(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkLoadingTaskEditor
}

extension URLSession: NetworkLoader {
	public func loadData(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkLoadingTaskEditor {
		let urlSessionTask = self.dataTask(with: request) { data, response, error in
			completion(data, response, error)
		}
		return NetworkHandlerDataTask(urlSessionTask)
	}
}

public enum NetworkLoadingTaskStatus {
	case running, suspended, canceling, completed
}

public protocol NetworkLoadingTask: AnyObject {
	var status: NetworkLoadingTaskStatus { get }

	var result: Result<Data?, Error>? { get }
	var downloadProgressUpdatedClosure: ((NetworkLoadingTask) -> Void)? { get set }
	var uploadProgressUpdatedClosure: ((NetworkLoadingTask) -> Void)? { get set }
	var onCompletion: ((NetworkLoadingTask) -> Void)? { get set }
	var countOfBytesExpectedToReceive: Int64 { get }
	var countOfBytesReceived: Int64 { get }
	var countOfBytesExpectedToSend: Int64 { get }
	var countOfBytesSent: Int64 { get }

	var priority: Float { get set }

	func resume()
	func cancel()
	func suspend()
}

public protocol NetworkLoadingTaskEditor: NetworkLoadingTask {
	var result: Result<Data?, Error>? { get set }
}
