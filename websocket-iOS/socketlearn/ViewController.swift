//
//  ViewController.swift
//  socketlearn
//
//  Created by lihe on 2017/8/30.
//  Copyright © 2017年 lihe. All rights reserved.
//

import UIKit
import CocoaAsyncSocket
import SwiftyJSON
import SocketIO



class ViewController: UIViewController {
    
    var socket:SocketIOClient? = nil
    

    @IBOutlet weak var sendTextField: UITextField!

    @IBOutlet weak var receivedTextfield: UITextView!

    var sendtext :String? = nil
    
    var reConnectTime = 0
    


    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(textFieldDidChange), name: NSNotification.Name.UITextFieldTextDidChange, object:sendTextField)
        
        receivedTextfield.delegate = self
        
        myconnect()
        
        mysocket { 
            print("连接成功")
        }
        
    }
    
    
    //发送消息
    @IBAction func sendMsg(_ sender: UIButton) {
        
        socket?.emit("message", sendtext ?? "不要发空的")
    }
    
    //断开连接
    @IBAction func disConnect(_ sender: Any) {
        
        socket?.disconnect()
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .UITextFieldTextDidChange, object: sendTextField)
    }
    
    
    //定时器心跳
    var timer: DispatchSourceTimer?
    
    fileprivate  func startTimer(time:DispatchTime) {
        let queue = DispatchQueue(label: "com.app.timer", attributes: .concurrent)
        
        timer?.cancel()        // cancel previous timer if any
        
        timer = DispatchSource.makeTimerSource(queue: queue)
        //心跳设置为3分钟，NAT超时一般为5分钟
        timer?.scheduleRepeating(deadline: time, interval: .seconds(3*60), leeway: .seconds(1))
        
        timer?.setEventHandler { [weak self] in
            //与服务器约定好标识heart
            self?.socket?.emit("message", "xxxxheart")
            
            print(Date())
        }
        
        timer?.resume()
    }
    
    fileprivate func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    

}

// MARK:-----socket逻辑---------------
extension ViewController{
    
    
    func myconnect() {
        if self.socket != nil {
            return
        }
        
        self.socket = SocketIOClient(socketURL: URL(string: "http://localhost:8080/")!, config: [.log(false)])
        self.socket?.reconnectWait = reConnectTime
    }
    
    //连接以及监听
    func mysocket(callback:@escaping ()->())  {
        //0服务器开机listen
        
        //1收到服务器的确认后,应答服务器,此后开始收发数据
        //监听连接connect
        socket?.on("connect") { (data, ack) in
            callback()
            self.setupHeart()
            print(data,ack)
        }
        /*
        //等价于上面的
        socket.on(clientEvent: .connect) { (data, ask) in
            
        }
        */
        
        
        //2,中间服务器应答客户端,连接成功
        //3客户端保持连接
        socket?.connect()
        
        //message要与服务端的socket字段对应,才能实现监听
        socket?.on("message") {[weak self] (data, ack) in
            print(data[0] as! String)
            self?.receivedTextfield.text = data[0] as! String
        }
        
        
        //监听断开连接
        socket?.on(clientEvent: .disconnect, callback: { (data, ack) in
            print("--->断开连接")
        })
        
        
        //监听错误
        socket?.on(clientEvent: SocketClientEvent.error) { [weak self](data, ack) in
            self?.reConnect()
        }
        
        //监听从新连接
        socket?.on(clientEvent: .reconnect) { (data, ack) in
            print("reconnect")
        }

    }
    
    //重连机制
    func reConnect()  {
        socket?.disconnect()
        self.socket = nil
        
        if (reConnectTime) > 64 { //超过1分钟就不重连了
            return
        }
        
        let deadLineTime = DispatchTime.now() + .seconds(reConnectTime)
        DispatchQueue.main.asyncAfter(deadline: deadLineTime) { [weak self] in
            self?.myconnect()
            //重连
            self?.mysocket {
                print("newconnect")
            }
        }
        
        if reConnectTime == 0 {
            reConnectTime = 2
        }else{
            reConnectTime *= 2
        }
        
    }
    
    //初始化心跳,就是添加一个定时器,发送固定字段
    func setupHeart() {
        DispatchQueue.main.async {
            self.destroyHeart();
            self.startTimer(time: .now())
        }
    }
    
    //取消心跳
    func destroyHeart()  {
        self.stopTimer()
    }

}


// MARK:-----delegate---------------
extension ViewController:UITextViewDelegate {
    
    func textFieldDidChange(noti:Notification) {
        let obj = noti.object as! UITextField
        sendtext = obj.text
        
    }
    
    func textViewDidChange(_ textView: UITextView) {
        print("textView.text \(textView.text)")
    }
}


