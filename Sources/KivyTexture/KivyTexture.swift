// The Swift Programming Language
// https://docs.swift.org/swift-book


import UIKit
import PySwiftCore
import PythonCore
import CoreGraphics
import PyCallable
import PyUnpack
import PyEncode






private func load_kivy_texture() -> PyPointer {
	let code = """
from kivy.graphics.texture import Texture
from kivy.graphics.texture import texture_create
"""
	let dict = PyDict_New()!
	
	if let result = PyRun_String(code, Py_file_input, dict, dict) {
		result.decref()
	} else {
		PyErr_Print()
	}
	pyPrint(dict)
	
	return dict
}
private let kv_tex_funcs = {
	let dict = load_kivy_texture()
	let funcs = try! [String:PyPointer](object: dict)
	return funcs
}()


extension UnsafeMutablePointer where Pointee == UInt8 {
	
	static func new(_ capacity: Int) -> Self {
		let ptr = Self.allocate(capacity: capacity)
		ptr.initialize(repeating: 0, count: capacity)
		return ptr
	}
}

func cgPixels(imageRef: CGImage) -> (UnsafeMutablePointer<UInt8>, Int) {

	let wh = imageRef
	let width = wh.width
	let height = wh.height
	let bytesPerRow = width * 4
	
	let size = bytesPerRow * height
	var colorSpace = CGColorSpaceCreateDeviceRGB()
	//var colorSpace: CGColorSpace = .init(name: CGColorSpace.sRGB)!
	
	//let pixels = PixelContainer(capacity: size)
	let pixels = UnsafeMutablePointer<UInt8>.new(size)
	let bounds = CGRect(x: 0, y: 0, width: width, height: height)
	
	let context = CGContext(
		data: pixels,
		width: width,
		height: height,
		bitsPerComponent: 8,
		bytesPerRow: bytesPerRow,
		space: colorSpace,
		bitmapInfo:
			CGImageAlphaInfo.premultipliedLast.rawValue
		
	)!

	context.setFillColor( .init(gray: 1, alpha: 1) )
	context.translateBy(x: 0, y: CGFloat(height))
	context.scaleBy(x: 1, y: -1)
	context.clip(to: bounds, mask: imageRef)
	
	
	context.fill(bounds)

	
	return (pixels, size)
}



public struct KivyTexture {
	
	static let texture_create = kv_tex_funcs["texture_create"]!
	static let rgba = "rgba".pyPointer
	static let create_kv_args = [
		"color_fmt": "rgba"
	].pyPointer
	static let blit_string = "blit_buffer".pyPointer
	
	public let data: PyPointer
	
	public init(width: Int, height: Int) {
		data = try! Self.texture_create([width, height])
	}
	
	public init(cg: CGImage) {
		
		let tex_size = [cg.width, cg.height].pyPointer
		guard let tex = PyObject_Vectorcall(Self.texture_create, [tex_size, Self.rgba], 2, nil) else {
			PyErr_Print()
			fatalError()
		}
		
		let (pixels, size) = cgPixels(imageRef: cg)
		
		var py_buffer = Py_buffer()
		PyBuffer_FillInfo(
			&py_buffer,
			nil,
			pixels,
			size,
			0,
			PyBUF_WRITE
		)
		let mem_view = PyMemoryView_FromBuffer(&py_buffer)
//		
		//let mem_view = PyMemoryView_FromObject(pixels)
		
		
		PyObject_VectorcallMethod(Self.blit_string, [tex, mem_view, .None, Self.rgba], 4, nil)
		
		tex_size.decref()
		//pixels.decref()
		mem_view?.decref()
		PyBuffer_Release(&py_buffer)
		pixels.deallocate()
		
		data = tex
	}
	
	public init(pixels: PyPointer, width: Int, height: Int) {
		
		let tex_size = [width, height].pyPointer
		//pyPrint(Self.texture_create)
		guard let tex = PyObject_Vectorcall(Self.texture_create, [tex_size, Self.rgba], 2, nil) else {
			PyErr_Print()
			fatalError()
		}
		data = tex
		let mem_view = PyMemoryView_FromObject(pixels)
		PyObject_VectorcallMethod(Self.blit_string, [tex, mem_view, tex_size, Self.rgba], 4, nil)
		tex_size.decref()
		mem_view?.decref()
		
	}
	
	public static func create(pixels: PyPointer, width: Int, height: Int) -> PyPointer {
		Self.init(pixels: pixels, width: width, height: height).data
	}
}



public protocol KivyTextureProtocol {
	func texture() -> PyPointer
}

extension CGImage: KivyTextureProtocol {
	public func texture() -> PyPointer {
		return KivyTexture(cg: self).data
//		if let pixels = cgPixels(imageRef: self)?.pyPointer {
//			let tex = KivyTexture(pixels: pixels, width: width, height: height).data
//			pixels.decref()
//			return tex
//		}
		
		return .None
	}
}

extension UIImage: KivyTextureProtocol {
	public func texture() -> PyPointer {
		if let cg = cgImage {
			return cg.texture()
		}
		return .None
	}
}
