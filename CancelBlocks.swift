//
//  CancelBlocks.swift
//  Smooth
//
//  Created by Evgenii Rtishchev on 16/02/15.
//  Copyright (c) 2015 Evgenii Rtishchev. All rights reserved.
//

typealias dispatch_cancelable_block_t = (_ cancel:Bool) -> (Void)

func dispatch_block_t(_ delay: Double, block: @escaping ()->()) -> dispatch_cancelable_block_t {
    var originalBlock: (()->())? = block
    var cancelableBlock: dispatch_cancelable_block_t? = nil
    
    let delayBlock: dispatch_cancelable_block_t = { cancel in
        if !cancel && originalBlock != nil {
            DispatchQueue.main.async(execute: originalBlock as! @convention(block) () -> Void)
        }
        cancelableBlock = nil
        originalBlock = nil
    }
    cancelableBlock = delayBlock
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { () -> Void in
        if let cancelableBlock = cancelableBlock {
            cancelableBlock(false)
        }
    }
    
    return cancelableBlock!
}

func dispatch_cancel_block_t(_ block:dispatch_cancelable_block_t?) {
    if let block = block {
        block(true)
    }
}


// Original code
//func dispatch_block_t(delay:Double, block:dispatch_block_t?) -> dispatch_cancelable_block_t? {
//    if (block == nil) {
//        return nil
//    }
//    var originalBlock:dispatch_block_t? = block!
//    var cancelableBlock:dispatch_cancelable_block_t? = nil
//    var delayBlock:dispatch_cancelable_block_t = {(cancel:Bool) -> Void in
//        if ((!cancel) && (originalBlock != nil)) {
//            dispatch_async(dispatch_get_main_queue(), originalBlock!)
//        }
//        cancelableBlock = nil
//        originalBlock = nil
//    }
//    cancelableBlock = delayBlock
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
//        if (cancelableBlock != nil) {
//            cancelableBlock!(cancel: false)
//        }
//    }
//    return cancelableBlock
//}
//
//func dispatch_cancel_block_t(block:dispatch_cancelable_block_t?) {
//    if (block != nil) {
//        block!(cancel: true)
//    }
//}
