module imageio

import os
import stbi
import libs.libraw
import arrays

// RGB values in the range [0, 255] (u8).
pub struct RGB {
pub mut:
	r u8
	g u8
	b u8
}

// RGB values in the range [0, 1] (f64).
pub struct RGBf64 {
pub mut:
	r f64
	g f64
	b f64
}

pub struct HSV {
pub mut:
	h f64
	s f64
	v f64
}

pub struct HSL {
pub mut:
	h f64
	s f64
	l f64
}

pub struct Image {
pub mut:
	width       int
	height      int
	nr_channels int
	data        []u8
}

@[direct_array_access]
pub fn (img Image) get_pixel(x int, y int) RGB {
	if img.nr_channels != 3 {
		panic('nr_channels must be 3')
	}
	index := (y * img.width + x) * img.nr_channels
	return RGB{
		r: img.data[index]
		g: img.data[index + 1]
		b: img.data[index + 2]
	}
}

@[direct_array_access]
pub fn (mut img Image) set_pixel(x int, y int, rgb RGB) {
	if img.nr_channels != 3 {
		panic('nr_channels must be 3')
	}
	index := (y * img.width + x) * img.nr_channels
	img.data[index] = rgb.r
	img.data[index + 1] = rgb.g
	img.data[index + 2] = rgb.b
}

pub fn load_image(image_path string) Image {
	// NOTE: since stbi automatically converts to RGBA (4 channels) when desired_channels, we don't need to do it here
	// NOTE: stbi_image.nr_channels is the number of channels in the image file, not of the buffer

	// load image
	params := stbi.LoadParams{
		desired_channels: 4
	}
	buffer := os.read_bytes(image_path) or { panic('failed to read image') }
	stbi_image := stbi.load_from_memory(buffer.data, buffer.len, params) or {
		panic('failed to load image')
	}
	defer {
		stbi_image.free()
	}
	mut data := unsafe {
		arrays.carray_to_varray[u8](stbi_image.data, stbi_image.width * stbi_image.height * 4)
	}

	image := Image{
		width:       stbi_image.width
		height:      stbi_image.height
		nr_channels: 4
		data:        data
	}
	return image
}

pub fn load_image_raw(image_path string) Image {
	libraw_data := libraw.libraw_init(.none_)
	println('libraw initialized')

	// Open the file and read the metadata
	mut status := libraw.libraw_open_file(libraw_data, image_path)
	println('file opened ${status}')

	// The metadata are accessible through data fields
	// dump(libraw_data.image)

	// Let us unpack the image
	status = libraw.libraw_unpack(libraw_data)
	println('unpacked ${status}')

	// Convert from imgdata.rawdata to imgdata.image using raw2image
	// status = libraw.libraw_raw2image(libraw_data)
	// println('raw2image ${status}')
	// dump(libraw_data.image)
	// buffer_size := libraw_data.sizes.iwidth * libraw_data.sizes.iheight
	// r := arrays.carray_to_varray[i16](libraw_data.image[0], buffer_size)
	// g := arrays.carray_to_varray[i16](libraw_data.image[1], buffer_size)
	// b := arrays.carray_to_varray[i16](libraw_data.image[2], buffer_size)
	// g2 := arrays.carray_to_varray[i16](libraw_data.image[3], buffer_size)

	// Convert from imgdata.rawdata to imgdata.image using dcraw_process
	status = libraw.libraw_dcraw_process(libraw_data)
	println('dcraw_process ${status}')
	libraw_processed_image := libraw.libraw_dcraw_make_mem_image(libraw_data, &status)
	println('dcraw_make_mem_image ${status}')
	dump(libraw_processed_image)

	println('libraw_processed_image.data ${libraw_processed_image.data}')

	mut data := unsafe { arrays.carray_to_varray[u8](libraw_processed_image.data, libraw_processed_image.data_size) }

	dump(libraw_processed_image.colors)

	if libraw_processed_image.colors == 3 {
		println('converting from RGB to RGBA')
		mut data_rgba := []u8{len: int(libraw_processed_image.width * libraw_processed_image.height * 4)}
		buf_rgb_to_rgba(mut data_rgba, data, libraw_processed_image.width * libraw_processed_image.height)
		data = data_rgba.clone()
	}
	println('data_rgba first 4 bytes ${data[0]} ${data[1]} ${data[2]} ${data[3]}')

	image := Image{
		width:       libraw_processed_image.width
		height:      libraw_processed_image.height
		nr_channels: 4
		data:        data
	}
	return image
}

pub fn load_image_raw2(image_path string, shared image Image) {
	libraw_data := libraw.libraw_init(.none_)
	println('libraw initialized')

	// Open the file and read the metadata
	mut status := libraw.libraw_open_file(libraw_data, image_path)
	println('file opened ${status}')

	// The metadata are accessible through data fields
	// dump(libraw_data.image)

	// Let us unpack the image
	status = libraw.libraw_unpack(libraw_data)
	println('unpacked ${status}')

	// Convert from imgdata.rawdata to imgdata.image using raw2image
	// status = libraw.libraw_raw2image(libraw_data)
	// println('raw2image ${status}')
	// dump(libraw_data.image)
	// buffer_size := libraw_data.sizes.iwidth * libraw_data.sizes.iheight
	// r := arrays.carray_to_varray[i16](libraw_data.image[0], buffer_size)
	// g := arrays.carray_to_varray[i16](libraw_data.image[1], buffer_size)
	// b := arrays.carray_to_varray[i16](libraw_data.image[2], buffer_size)
	// g2 := arrays.carray_to_varray[i16](libraw_data.image[3], buffer_size)

	// Convert from imgdata.rawdata to imgdata.image using dcraw_process
	status = libraw.libraw_dcraw_process(libraw_data)
	println('dcraw_process ${status}')
	libraw_processed_image := libraw.libraw_dcraw_make_mem_image(libraw_data, &status)
	println('dcraw_make_mem_image ${status}')
	dump(libraw_processed_image)

	println('libraw_processed_image.data ${libraw_processed_image.data}')

	mut data := unsafe { arrays.carray_to_varray[u8](libraw_processed_image.data, libraw_processed_image.data_size) }

	println(libraw_processed_image.colors)

	if libraw_processed_image.colors == 3 {
		println('converting from RGB to RGBA')
		mut data_rgba := []u8{len: int(libraw_processed_image.width * libraw_processed_image.height * 4)}
		buf_rgb_to_rgba(mut data_rgba, data, libraw_processed_image.width * libraw_processed_image.height)
		data = data_rgba.clone()
	}
	println('data_rgba first 4 bytes ${data[0]} ${data[1]} ${data[2]} ${data[3]}')

	// image
	lock image {
		image.width = libraw_processed_image.width
		image.height = libraw_processed_image.height
		image.nr_channels = 4
		image.data = data
	}
}

pub fn (img Image) save_bmp(image_path string) {
	stbi.stbi_write_bmp(image_path, img.width, img.height, img.nr_channels, img.data.data) or {
		panic('failed to write image')
	}
}

pub fn (img Image) clone() Image {
	mut data := []u8{len: img.data.len}
	for i := 0; i < img.data.len; i++ {
		data[i] = img.data[i]
	}
	return Image{
		width:       img.width
		height:      img.height
		nr_channels: img.nr_channels
		data:        data
	}
}

@[direct_array_access]
pub fn buf_rgb_to_rgba(mut buf_rgba []u8, buf_rgb []u8, size int) {
	for i := 0; i < size; i++ {
		buf_rgba[i * 4 + 0] = buf_rgb[i * 3 + 0]
		buf_rgba[i * 4 + 1] = buf_rgb[i * 3 + 1]
		buf_rgba[i * 4 + 2] = buf_rgb[i * 3 + 2]
		buf_rgba[i * 4 + 3] = 0xFF
	}
}
