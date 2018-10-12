//
//  Constants.swift
//  PixelCity
//
//  Created by Rohan Bardekar on 20/09/18.
//  Copyright © 2018 Rohan Bardekar. All rights reserved.
//

import Foundation

let apiKey = ""



func flickrURL(forAPIKey key: String, withAnnotation annotation: DroppablePin, andNumberOfPhotos number: Int) -> String {
    return "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(apiKey)&lat=\(annotation.coordinate.latitude)&lon=\(annotation.coordinate.longitude)&radius=1&radius_units=mi&per_page=\(number)&format=json&nojsoncallback=1"
  
}
