//
//  OktaLoggerFileLogger.swift
//  OktaLogger
//
//  Created by Kaushik Krishnakumar on 7/9/20.
//  Copyright © 2020 Okta, Inc. All rights reserved.
//

import Foundation
import CocoaLumberjack

@objc
public class OktaLoggerFileLogger : OktaLoggerDestinationBase {
    var fileLogger:DDFileLogger = DDFileLogger();
    var isLoggingActive:Bool = true;
    var logDirectory: String = "logs";
    
    /**
     Initilalize logger with log files in `logDirectory`
     */
    @objc
    convenience public init(logDirectory: String, identifier: String, level:OktaLoggerLogLevel, defaultProperties:[AnyHashable: Any]?) {
        self.init(identifier:identifier, level:level, defaultProperties:defaultProperties);
    }
    
    @objc
    override public init(identifier: String, level: OktaLoggerLogLevel, defaultProperties: [AnyHashable : Any]?) {
        super.init(identifier: identifier, level: level, defaultProperties: defaultProperties)
        self.setupLogger()
    }
    
    @objc
    override public func log(level: OktaLoggerLogLevel, eventName: String, message: String?, properties: [AnyHashable : Any]?, file: String, line: NSNumber, funcName: String) {
        
        let logMessage = self.stringValue(level: level,
                                          eventName: eventName,
                                          message: message,
                                          file: file, line: line, funcName: funcName)
        // translate log level into relevant console type level
        self.log(level: level, message:logMessage)
    }
    
    /**
     Stop logging after 'x' seconds
     */
    @objc
    public func stopLoggingAfter(expiryInMilliSeconds:TimeInterval) {
        // Async Task/Timer to remove after 'x' seconds
        Timer.scheduledTimer(withTimeInterval:expiryInMilliSeconds , repeats: false) { timer in
            self.isLoggingActive = false;
            DDLog.remove(self.fileLogger)
            timer.invalidate()
        }
    }
    
    /**
     Stop logging immediately
     */
    @objc
    public func stopLogging() {
        self.stopLoggingAfter(expiryInMilliSeconds: 0);
    }
    
    /**
     Reinitialize logger
     */
    @objc
    public func resetLogging() {
        self.stopLogging()
        let logFilePath = URL(fileURLWithPath: self.logDirectoryAbsolutePath()!)
        let text = ""
        do {
            try text.write(to: logFilePath, atomically: false, encoding: .utf8)
        } catch {
            print(error)
        }
    }
    
    /**
     Log file path
     */
    @objc
    public func logDirectoryAbsolutePath() -> String?  {
        let path: String? = self.fileLogger.currentLogFileInfo?.filePath
        return path
    }
    
    @objc
    public func getLogs() -> [NSData] {
        var logFileDataArray:[NSData] = [NSData]();
        let logFilePaths = self.fileLogger.logFileManager.unsortedLogFilePaths
        for logFilePath in logFilePaths {
            let fileURL = NSURL(fileURLWithPath: logFilePath)
            if let logFileData = try? NSData(contentsOf: fileURL as URL, options: NSData.ReadingOptions.mappedIfSafe) {
                // Insert at front to reverse the order, so that oldest logs appear first.
                logFileDataArray.insert(logFileData, at: 0)
            }
        }
        return logFileDataArray
    }
    /**
     Remove all Loggers during de allocate
     */
    deinit {
        DDLog.remove(self.fileLogger)
    }
    
    /**
     Configure Logger Parameters
     */
    func setupLogger() {
        let logExpiryDay:Double = 60*60*24
        let logExpiryDefault: Double = logExpiryDay * 2
        self.fileLogger.rollingFrequency = logExpiryDefault // 48 hours
        self.fileLogger.logFileManager.maximumNumberOfLogFiles = 1
        DDLog.add(self.fileLogger)
        self.stopLoggingAfter(expiryInMilliSeconds:logExpiryDefault)
        self.isLoggingActive = true
    }
    
    /**
     Create a structured string out of the logging parameters and properties
     */
    func stringValue(level: OktaLoggerLogLevel, eventName: String, message: String?, file: String, line: NSNumber, funcName: String) -> String {
        let filename = file.split(separator: "/").last
        let logMessageIcon = OktaLoggerLogLevel.logMessageIcon(level: level)
        return "{\(logMessageIcon) \"\(eventName)\": {\"message\": \"\(message ?? "")\", \"location\": \"\(filename ?? ""):\(funcName):\(line)\"}}"
    }
    
    /**
     Translate OktaLoggerLogLevel into a console-friendly OSLogType value
     */
    func log(level: OktaLoggerLogLevel, message:String) {
        switch level {
        case .debug:
            return DDLogDebug(message);
        case .info, .uiEvent:
            return DDLogInfo(message)
        case .error:
            return DDLogError(message)
        case .warning:
            return DDLogWarn(message)
        default:
            return DDLogWarn(message)
        }
    }
}
