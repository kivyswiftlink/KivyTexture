//
//  File.swift
//  
//
//  Created by CodeBuilder on 22/09/2024.
//

import Foundation
import PySwiftCore
import PythonCore
import PyEncode
import PyUnpack

class PixelContainer: PyEncodable {
	let data: UnsafeMutablePointer<UInt8>
	//let width: Int
	//let height: Int
	let capacity: Int
	
	init(capacity: Int) {
		//let size = width * height * numberOfComponents
		let data = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
		data.initialize(repeating: 0, count: capacity)
		
		self.data = data
//		self.width = width
//		self.height = height
		self.capacity = capacity
	}
	deinit {
		data.deallocate()
	}
	
	static var PyBuffer: PyBufferProcs = .init(
		bf_getbuffer: { s, buffer, rw in
			let cls: PixelContainer = UnPackPyPointer(from: s)
			return PyBuffer_FillInfo(
				buffer,
				s,
				cls.data,
				cls.capacity,
				0,
				rw
			)
		},
		bf_releasebuffer: nil
	)
	
	var pyPointer: PyPointer { Self.asPyPointer(self) }
}
