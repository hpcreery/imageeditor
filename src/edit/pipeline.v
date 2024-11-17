module edit

// import processing.image
import processing
import imageio
import benchmark

pub struct PixelPipeline {
pub mut:
	backend processing.Backend
	dirty   bool
	edits   []&Edit
}

pub fn init_pixelpipeline() PixelPipeline {
	mut edits := []&Edit{}
	edits << Invert.new()
	return PixelPipeline{
		backend: processing.Backend.new()
		edits:   edits
	}
}

pub fn (mut pixpipe PixelPipeline) process(img imageio.Image, mut new_img imageio.Image) {
	// make new_img a copy of img
	new_img.data = img.data

	// don't process if no edits are enabled
	mut any_enabled := false
	for mut edit in pixpipe.edits {
		if edit.enabled {
			any_enabled = true
			break
		}
	}
	if !any_enabled {
		pixpipe.dirty = false
		return
	}

	mut b := benchmark.start()

	pixpipe.backend.load_image(img)
	b.measure('load_image')

	// process edits
	for mut edit in pixpipe.edits {
		if edit.enabled {
			edit.process(mut pixpipe.backend)
			b.measure('process ${edit.name}')
		}
	}

	dump(new_img.width)
	dump(new_img.height)
	dump(new_img.nr_channels)
	pixpipe.backend.read_image(mut new_img)
	dump(new_img.width)
	dump(new_img.height)
	dump(new_img.nr_channels)
	b.measure('read_image')

	pixpipe.dirty = false
}

pub fn (mut pixpipe PixelPipeline) shutdown() {
	pixpipe.backend.shutdown()
}
