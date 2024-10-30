module imageio

import sync
import runtime
import math

enum LoadStatus {
	loading
	loaded
	failed
}

struct ManagedImage {
pub mut:
	path  string
	image ?Image

	// on_load fn (self &ManagedImage) = unsafe { nil }
	status LoadStatus
}

pub struct Catalog {
pub mut:
	images []ManagedImage
}

pub fn Catalog.new() Catalog {
	return Catalog{
		images: []ManagedImage{}
	}
}

pub fn (mut c Catalog) spawn_load_images_by_path(paths []string) {
	file_chan := chan string{cap: 1000}
	managed_image_chan := chan ManagedImage{cap: 1000}

	// create a worker to load image paths
	spawn fn [paths, file_chan] () {
		for path in paths {
			file_chan <- path
		}
		file_chan.close()
	}()

	// create workers to load images
	spawn c.spawn_load_image_workers(managed_image_chan, file_chan)

	// create worker to collect images
	spawn fn [mut c, managed_image_chan] () {
		for {
			managed_image := <-managed_image_chan or { break }
			c.images << managed_image
		}
	}()
}

pub fn (mut c Catalog) spawn_load_image_workers(managed_image_chan chan ManagedImage, filepath_chan chan string) {
	mut wg := sync.new_waitgroup()
	cpus := runtime.nr_cpus()
	workers := math.max(cpus - 4, 1)
	dump('loading images with ${workers} workers')
	wg.add(workers)
	for j := 0; j < workers; j++ {
		spawn fn [filepath_chan, mut wg, mut c, managed_image_chan] () {
			for {
				filepath := <-filepath_chan or { break }
				dump('loading image: ${filepath}')
				image := load_image_raw(filepath)
				managed_image_chan <- ManagedImage{
					path:   filepath
					image:  image
					status: LoadStatus.loaded
				}
				dump('loaded image: ${filepath}')
			}
			dump('worker done')

			wg.done()
		}()
	}

	dump('wg done')
	wg.wait()
	managed_image_chan.close()
}