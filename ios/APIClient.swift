//
//  APIClient.swift
//  NetworkClient
//
//  Created by Miguel Alatzar on 10/6/20.
//  Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
//  See LICENSE.txt for license information.
//

import Alamofire
import SwiftyJSON
import SwiftKeychainWrapper

@objc(APIClient)
class APIClient: NetworkClient {
    
    @objc(createClientFor:withOptions:withResolver:withRejecter:)
    func createClientFor(baseUrlString: String, options: Dictionary<String, Any>?, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        guard let baseUrl = URL(string: baseUrlString) else {
            rejectMalformed(url: baseUrlString, withRejecter: reject)
            return
        }

        let options = JSON(options)
        if options != JSON.null {
            let configuration = getURLSessionConfiguration(from: options)
            let redirectHandler = getRedirectHandler(from: options)
            let interceptor = getInterceptor(from: options)
            let cancelRequestsOnUnauthorized = options["sessionConfiguration"]["cancelRequestsOnUnauthorized"].boolValue
            let bearerAuthTokenResponseHeader = options["requestAdapterConfiguration"]["bearerAuthTokenResponseHeader"].string

            resolve(
                SessionManager.default.createSession(for: baseUrl,
                                                     withConfiguration: configuration,
                                                     withInterceptor: interceptor,
                                                     withRedirectHandler: redirectHandler,
                                                     withCancelRequestsOnUnauthorized: cancelRequestsOnUnauthorized,
                                                     withBearerAuthTokenResponseHeader: bearerAuthTokenResponseHeader)
            )

            return
        }
        
        resolve(SessionManager.default.createSession(for: baseUrl))
    }

    @objc(invalidateClientFor:withResolver:withRejecter:)
    func invalidateClientFor(baseUrlString: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {        
        guard let baseUrl = URL(string: baseUrlString) else {
            rejectMalformed(url: baseUrlString, withRejecter: reject)
            return
        }

        KeychainWrapper.standard.removeObject(forKey: baseUrl.host!)

        resolve(SessionManager.default.invalidateSession(for: baseUrl))
    }

    @objc(addClientHeadersFor:withHeaders:withResolver:withRejecter:)
    func addClientHeadersFor(baseUrlString: String, headers: Dictionary<String, String>, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        guard let baseUrl = URL(string: baseUrlString) else {
            rejectMalformed(url: baseUrlString, withRejecter: reject)
            return
        }

        if SessionManager.default.getSession(for: baseUrl) == nil {
            rejectInvalidSession(for: baseUrl, withRejecter: reject)
            return
        }

        resolve(SessionManager.default.addSessionHeaders(for: baseUrl, additionalHeaders: headers))
    }

    @objc(getClientHeadersFor:withResolver:withRejecter:)
    func getClientHeadersFor(baseUrlString: String, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        guard let baseUrl = URL(string: baseUrlString) else {
            rejectMalformed(url: baseUrlString, withRejecter: reject)
            return
        }

        if SessionManager.default.getSession(for: baseUrl) == nil {
            rejectInvalidSession(for: baseUrl, withRejecter: reject)
            return
        }

        let headers = JSON(SessionManager.default.getSessionHeaders(for: baseUrl)).dictionaryObject
        resolve(headers)
    }
    
    @objc(get:forEndpoint:withOptions:withResolver:withRejecter:)
    func get(baseUrl: String, endpoint: String, options: Dictionary<String, Any>, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        handleRequest(for: baseUrl, withEndpoint: endpoint, withMethod: .get, withOptions: JSON(options), withResolver: resolve, withRejecter: reject)
    }

    @objc(put:forEndpoint:withOptions:withResolver:withRejecter:)
    func put(baseUrl: String, endpoint: String, options: Dictionary<String, Any>, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        handleRequest(for: baseUrl, withEndpoint: endpoint, withMethod: .put, withOptions: JSON(options), withResolver: resolve, withRejecter: reject)
    }
    
    @objc(post:forEndpoint:withOptions:withResolver:withRejecter:)
    func post(baseUrl: String, endpoint: String, options: Dictionary<String, Any>, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        handleRequest(for: baseUrl, withEndpoint: endpoint, withMethod: .post, withOptions: JSON(options), withResolver: resolve, withRejecter: reject)
    }

    @objc(patch:forEndpoint:withOptions:withResolver:withRejecter:)
    func patch(baseUrl: String, endpoint: String, options: Dictionary<String, Any>, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        handleRequest(for: baseUrl, withEndpoint: endpoint, withMethod: .patch, withOptions: JSON(options), withResolver: resolve, withRejecter: reject)
    }

    @objc(delete:forEndpoint:withOptions:withResolver:withRejecter:)
    func delete(baseUrl: String, endpoint: String, options: Dictionary<String, Any>, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        handleRequest(for: baseUrl, withEndpoint: endpoint, withMethod: .delete, withOptions: JSON(options), withResolver: resolve, withRejecter: reject)
    }
    
    func handleRequest(for baseUrlString: String, withEndpoint endpoint: String, withMethod method: HTTPMethod, withOptions options: JSON, withResolver resolve: @escaping RCTPromiseResolveBlock, withRejecter reject: RCTPromiseRejectBlock) -> Void {
        guard let baseUrl = URL(string: baseUrlString) else {
            rejectMalformed(url: baseUrlString, withRejecter: reject)
            return
        }
    
        guard let session = SessionManager.default.getSession(for: baseUrl) else {
            rejectInvalidSession(for: baseUrl, withRejecter: reject)
            return
        }

        let url = baseUrl.appendingPathComponent(endpoint)
        handleRequest(for: url, withMethod: method, withSession: session, withOptions: options, withResolver: resolve, withRejecter: reject)
    }

    override func handleResponse(for session: Session, withUrl url: URL, withData data: AFDataResponse<Any>) {
        if data.response?.statusCode == 401 && session.cancelRequestsOnUnauthorized {
            session.cancelAllRequests()
        } else if let tokenHeader = session.bearerAuthTokenResponseHeader {
            if let token = data.response?.allHeaderFields[tokenHeader] as? String {
                KeychainWrapper.standard.set(token, forKey: url.host!)
            }
        }
    }
    
    func getURLSessionConfiguration(from options: JSON) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        
        if let headers = options["headers"].dictionaryObject {
            config.httpAdditionalHeaders = headers
        }
        
        let sessionOptions = options["sessionConfiguration"]
        if sessionOptions["allowsCellularAccess"].exists() {
            config.allowsCellularAccess = sessionOptions["allowsCellularAccess"].boolValue
        }

        if sessionOptions["timeoutIntervalForRequest"].exists() {
            config.timeoutIntervalForRequest = sessionOptions["timeoutIntervalForRequest"].doubleValue
        }

        if sessionOptions["timeoutIntervalForResource"].exists() {
            config.timeoutIntervalForResource = sessionOptions["timeoutIntervalForResource"].doubleValue
        }

        if sessionOptions["httpMaximumConnectionsPerHost"].exists() {
            config.httpMaximumConnectionsPerHost = sessionOptions["httpMaximumConnectionsPerHost"].intValue
        }
        
        if #available(iOS 11.0, *) {
            if sessionOptions["waitsForConnectivity"].exists() {
                config.waitsForConnectivity = sessionOptions["waitsForConnectivity"].boolValue
            }
        }

        return config
    }

    func rejectInvalidSession(for baseUrl: URL, withRejecter reject: RCTPromiseRejectBlock) -> Void {
        let message = "Session for \(baseUrl.absoluteString) has been invalidated"
        let error = NSError(domain: "com.mattermost.react-native-network-client", code: NSCoderValueNotFoundError, userInfo: [NSLocalizedDescriptionKey: message])
        reject("\(error.code)", message, error)
    }

    func getRedirectHandler(from options: JSON) -> RedirectHandler? {
        if options["followRedirects"].exists() {
            return Redirector(behavior: options["followRedirects"].boolValue ? .follow : .doNotFollow)
        }

        return nil
    }
}