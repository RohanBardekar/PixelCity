//
//  MapVC.swift
//  PixelCity
//
//  Created by Rohan Bardekar on 14/09/18.
//  Copyright © 2018 Rohan Bardekar. All rights reserved.
//

import UIKit
import MapKit
//Location Services to access user Location set in Utilities Panel
import CoreLocation
import Alamofire
import AlamofireImage


class MapVC: UIViewController, UIGestureRecognizerDelegate {

    @IBOutlet weak var pullUpViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var mapViewBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var pullUpView: UIView!
    @IBOutlet weak var mapView: MKMapView!
    
    //Create Instance of CLLocationManager
    var locationManager = CLLocationManager()
    
    let authorizationStatus = CLLocationManager.authorizationStatus()
    
    let regionRadius: Double = 1000
    
    var spinner: UIActivityIndicatorView?
    var progressLabel: UILabel?
    
    var screenSize = UIScreen.main.bounds
    
    var collectionView: UICollectionView?
    var flowLayout = UICollectionViewFlowLayout()
    
    var imageURLArray = [String]()
    var imageArray = [UIImage]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //We want this MapVC to be the delegate of mapView
        mapView.delegate = self
        //We need to set the delegate of locationManager
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.mapView.showsUserLocation = true
        configureLocationServices()
        addDoubleTapped()
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
        collectionView?.register(PhotoCell.self, forCellWithReuseIdentifier: "photoCell")
        collectionView?.delegate = self
        collectionView?.dataSource = self
        collectionView?.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        pullUpView.addSubview(collectionView!)
        
        registerForPreviewing(with: self, sourceView: collectionView!)
        
        
    }
    
    func addDoubleTapped(){
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(dropPin(sender:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        mapView.addGestureRecognizer(doubleTap)
    }

    func animateViewUp(){
        pullUpViewHeightConstraint.constant = 300
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    func addSwipe(){
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(animateViewDown))
        swipe.direction = .down
        pullUpView.addGestureRecognizer(swipe)
        
    }
    
    @objc func animateViewDown(){
        cancelAllSessions()
        pullUpViewHeightConstraint.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    func addSpinner(){
        spinner = UIActivityIndicatorView()
        spinner?.center = CGPoint(x: (screenSize.width/2) - (((spinner?.frame.width)!)/2), y: 150)
        spinner?.style = .whiteLarge
        spinner?.color = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        spinner?.startAnimating()
        collectionView?.addSubview(spinner!)
    }
    
    func removeSpinner(){
        if spinner != nil {
            spinner?.removeFromSuperview()
        }
    }
    
    func addProgressLabel(){
        progressLabel = UILabel()
        progressLabel?.frame = CGRect(x: (screenSize.width / 2) - 120, y: 175, width: 240, height: 40)
        progressLabel?.font = UIFont(name: "Avenir Next", size: 14)
        progressLabel?.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        progressLabel?.textAlignment = .center
//      progressLabel?.text = "Photos Loaded"
        collectionView?.addSubview(progressLabel!)
    }
    
    func removeProgressLabel(){
        if progressLabel != nil {
            progressLabel?.removeFromSuperview()
        }
    }
    
    @IBAction func centerMapButtonWasPressed(_ sender: Any){
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            centerMapOnUserLocation()
        }
    }

}

//To access the core features of MKMapView
extension MapVC: MKMapViewDelegate{
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if annotation is MKUserLocation{
            return nil
        }
        
        let pinAnnotation = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "droppablePin")
        pinAnnotation.pinTintColor = #colorLiteral(red: 0.4392156899, green: 0.01176470611, blue: 0.1921568662, alpha: 1)
        pinAnnotation.animatesDrop = true
        return pinAnnotation
    }
    
    func centerMapOnUserLocation(){
        guard let coordinate = locationManager.location?.coordinate else {
            return
        }
        let coordinateRegion = MKCoordinateRegion.init(center: coordinate, latitudinalMeters: regionRadius * 2.0, longitudinalMeters: regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    @objc func dropPin(sender: UITapGestureRecognizer){
        removePin()
        removeSpinner()
        removeProgressLabel()
        cancelAllSessions()
        
        imageURLArray = []
        imageArray = []
        collectionView?.reloadData()
        
        animateViewUp()
        addSwipe()
        addSpinner()
        addProgressLabel()
        
        
        
        let touchPoint = sender.location(in: mapView)
        let touchCoordiante = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        
        let annotation = DroppablePin(coordinate: touchCoordiante, identifier: "droppablePin")
        mapView.addAnnotation(annotation)
        //print(flickrURL(forAPIKey: apiKey, withAnnotation: annotation, andNumberOfPhotos: 40))
        let coordianteRegion = MKCoordinateRegion.init(center: touchCoordiante, latitudinalMeters: regionRadius * 2.0, longitudinalMeters: regionRadius * 2.0)
        mapView.setRegion(coordianteRegion, animated: true)
        retrieveURLs(forAnnotation: annotation) { (finished) in
            if finished {
                self.retrieveImages(handler: { (finished) in
                    if finished{
                        self.removeSpinner()
                        self.removeProgressLabel()
                        self.collectionView?.reloadData()
                    }
                })
            }
        }
    }
    
    func removePin(){
        for annotation in mapView.annotations {
            mapView.removeAnnotation(annotation)
        }
    }
    
    func retrieveURLs(forAnnotation annotation: DroppablePin, handler: @escaping (_ status: Bool) -> ()){
        Alamofire.request(flickrURL(forAPIKey: apiKey, withAnnotation: annotation, andNumberOfPhotos: 40)).responseJSON { (response) in
            
            guard let json = response.result.value as? Dictionary<String, AnyObject> else {return}
            let photosDictionary = json["photos"] as! Dictionary<String, AnyObject>
            let photoDictionaryArray = photosDictionary["photo"] as! [Dictionary<String, AnyObject>]
            for photo in photoDictionaryArray {
                let postURL = "https://farm\(photo["farm"]!).staticflickr.com/\(photo["server"]!)/\(photo["id"]!)_\(photo["secret"]!)_h_d.jpg"
                self.imageURLArray.append(postURL)
            }
            handler(true)
        }
    }
    
    func retrieveImages(handler: @escaping (_ status: Bool) -> ()){
        for url in imageURLArray {
            Alamofire.request(url).responseImage { (response) in
                guard let image = response.result.value else { return }
                self.imageArray.append(image)
                self.progressLabel?.text = "\(self.imageArray.count)/40 Images Download"
                
                if self.imageArray.count == self.imageURLArray.count {
                    handler(true)
                }
            }
        }
    }
    
    func cancelAllSessions(){
        Alamofire.SessionManager.default.session.getTasksWithCompletionHandler { (sessionDataTask, uploadData, downloadData) in
            sessionDataTask.forEach({ $0.cancel() })
            downloadData.forEach({ $0.cancel() })
        }
    }
}

extension MapVC: CLLocationManagerDelegate{
    
    //Custom Func
    func configureLocationServices(){
        if authorizationStatus == .notDetermined{
            locationManager.requestAlwaysAuthorization()
        } else{
            return
        }
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        centerMapOnUserLocation()
    }
}

extension MapVC: UICollectionViewDelegate, UICollectionViewDataSource{
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? PhotoCell else { return UICollectionViewCell() }
        
        let imageFromIndex = imageArray[indexPath.row]
        let imageView = UIImageView(image: imageFromIndex)
        cell.addSubview(imageView)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let popVC = storyboard?.instantiateViewController(withIdentifier: "PopVC") as? PopVC else { return }
        popVC.initData(forImage: imageArray[indexPath.row])
        present(popVC, animated: true, completion: nil)
    }
    
}

extension MapVC: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = collectionView?.indexPathForItem(at: location), let cell = collectionView?.cellForItem(at: indexPath) else { return nil}
        guard let popVC = storyboard?.instantiateViewController(withIdentifier: "PopVC") as? PopVC else { return nil }
        popVC.initData(forImage: imageArray[indexPath.row])
        previewingContext.sourceRect = cell.contentView.frame
        return popVC
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        show(viewControllerToCommit, sender: self)
    }
    
    
}
