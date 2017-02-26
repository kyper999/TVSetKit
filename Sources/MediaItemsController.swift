import UIKit
import SwiftyJSON

open class MediaItemsController: InfiniteCollectionViewController {
  public class var SegueIdentifier: String { return  "MediaItems" }
  var CellIdentifier: String { return  "MediaItemCell" }
  var HeaderViewIdentifier: String { return  "MediaItemsHeader" }
  var localizer = Localizer("com.rubikon.TVSetKit")

  static public func instantiate() -> Self {
    let bundle = Bundle(identifier: "com.rubikon.TVSetKit")!

    return AppStoryboard.instantiateController("Player", bundle: bundle, viewControllerClass: self)
  }

//  static public func instantiate() -> UINavigationController {
//    let bundle = Bundle(identifier: "com.rubikon.TVSetKit")!
//
//    let storyboard: UIStoryboard = UIStoryboard(name: "Player", bundle: bundle)
//
//    return storyboard.instantiateViewController(withIdentifier: storyboardID) as! UINavigationController
//  }

  public var displayTitle = true

  override open func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.title = ""
    clearsSelectionOnViewWillAppear = false

    collectionView?.backgroundView = activityIndicatorView
    adapter.spinner = PlainSpinner(activityIndicatorView)

    loadInitialData()
  }

  // MARK: UICollectionViewDataSource

  override open func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }

  override open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return items.count
  }

  override open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellIdentifier, for: indexPath) as! MediaItemCell

    let item = items[indexPath.row]

    let localizedName = localizer.localize(item.name!)

    cell.configureCell(item: item, localizedName: localizedName, target: self, action: #selector(self.tapped(_:)))

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tapped(_:)))

    tapGesture.allowedPressTypes = [NSNumber(value: UIPressType.playPause.rawValue)]

    cell.addGestureRecognizer(tapGesture)

    let itemSize = (collectionView.collectionViewLayout as! UICollectionViewFlowLayout).itemSize

    cell.thumb.frame = CGRect(x: 10, y: 0, width: itemSize.width, height: itemSize.height)
    cell.title.frame = CGRect(x: 10, y: itemSize.height, width: itemSize.width, height: 100)

    if !displayTitle {
      cell.title.text = ""
    }

    return cell
  }

  override open func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let currentOffset = scrollView.contentOffset.y
    let maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height
    let deltaOffset = maximumOffset - currentOffset

    if deltaOffset <= 0 {
      if adapter.nextPageAvailable(dataCount: items.count, index: items.count-1) {
        loadMoreData(items.count-1)
      }
    }
  }

  override open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let mediaItem = items[indexPath.row]

    let view = collectionView.cellForItem(at: indexPath)

    if mediaItem.isContainer() {
      navigate(from: mediaItem, view: view!)
    }
    else {
      performSegue(withIdentifier: VideoPlayerController.SegueIdentifier, sender: view)
    }
  }

  func tapped(_ gesture: UITapGestureRecognizer) {
    let indexPath = collectionView?.indexPath(for: gesture.view as! UICollectionViewCell)
    let mediaItem = items[indexPath!.row]

    if mediaItem.isContainer() {
      navigate(from: mediaItem, view: view)
    }
    else {
      performSegue(withIdentifier: VideoPlayerController.SegueIdentifier, sender: gesture.view!)
    }
  }

  func navigate(from mediaItem: MediaItem, view: UIView) {
    let type = mediaItem.type

    if type != nil && type!.isEmpty {
      mediaItem.resolveType()
    }

    if mediaItem.isContainer() {
      if mediaItem.isAudioContainer() {
        performSegue(withIdentifier: AudioItemsController.SegueIdentifier, sender: view)
      }
      else {
        let newAdapter = adapter.clone()
        newAdapter.selectedItem = mediaItem

        newAdapter.parentId = mediaItem.id
        newAdapter.parentName = mediaItem.name
        newAdapter.isContainer = true

        let destination = MediaItemsController.instantiate()

        destination.adapter = newAdapter

        destination.collectionView?.collectionViewLayout = adapter.buildLayout()!

        self.present(destination, animated: true)
      }
    }
    else {
      performSegue(withIdentifier: MediaItemDetailsController.SegueIdentifier, sender: view)
    }
  }

  // MARK: Navigation

  override open func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let identifier = segue.identifier {
      let selectedCell = sender as! MediaItemCell

      let indexPath = collectionView?.indexPath(for: selectedCell)!
      let mediaItem = items[indexPath!.row]

      switch identifier {
        case MediaItemDetailsController.SegueIdentifier:
          if let destination = segue.destination as? MediaItemDetailsController {
            destination.collectionItems = items
            destination.mediaItem = mediaItem
            destination.adapter = adapter
          }
        case AudioItemsController.SegueIdentifier:
          if let destination = segue.destination as? AudioItemsController {
            destination.mediaItem = mediaItem
            destination.adapter = adapter
            destination.adapter.selectedItem = mediaItem
          }
        case VideoPlayerController.SegueIdentifier:
          if let destination = segue.destination as? VideoPlayerController {
            destination.playVideo = true
            destination.collectionItems = items
            destination.mediaItem = mediaItem
            destination.adapter = adapter
            destination.provider = adapter.provider

            do {
              let bitrates = try mediaItem.getBitrates()

              if !bitrates.isEmpty {
                destination.bitrate = bitrates[0]
              }
            }
            catch {
              print("Error getting bitrate")
            }
          }
        default: break
      }
    }
  }

  override open func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                               at indexPath: IndexPath) -> UICollectionReusableView {
    if kind == "UICollectionElementKindSectionHeader" {
      let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
        withReuseIdentifier: HeaderViewIdentifier, for: indexPath as IndexPath) as! MediaItemsHeaderView

      headerView.sectionLabel.text = localizer.localize(getHeaderName())
      
      return headerView
    }

    return UICollectionReusableView()
  }

  func getHeaderName() -> String {
    var name = ""

    if adapter.getParentName() != nil {
      name = adapter.getParentName()!
    }
    else {
      name = adapter.requestType!
    }

    return name
  }

#if os(tvOS)
  override open func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
    cellSelection.setIndexPath(indexPath)

    let item = items[indexPath.row]

    navigationItem.title = item.name

    manageMovieBookmark()

    return true
  }
#endif

  // MARK:- Add Cell

  func manageMovieBookmark() {
    if adapter.requestType != "HISTORY" {
      let selectedItem = getSelectedItem()

      if let item = selectedItem {
        if adapter.requestType == "BOOKMARKS" {
          self.present(buildRemoveBookmarkController(item), animated: false, completion: nil)
        }
        else {
          self.present(buildAddBookmarkController(item), animated: false, completion: nil)
        }
      }
    }
  }

  func buildRemoveBookmarkController(_ item: MediaItem) -> UIAlertController {
    let title = localizer.localize("BOOKMARK_WILL_BE_REMOVED")
    let message = localizer.localize("CONFIRM_YOUR_CHOICE")
    
    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
    
    let okAction = UIAlertAction(title: "OK", style: .default) { (action) in
      let result = self.adapter.removeBookmark(item: item)
      
      if result {
        self.removeCell()
      }
      else {
        print("Bookmark already removed")
      }
    }
    
    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
    
    alertController.addAction(cancelAction)
    alertController.addAction(okAction)
    
    return alertController
  }
  
  func buildAddBookmarkController(_ item: MediaItem) -> UIAlertController {
    let title = localizer.localize("BOOKMARK_WILL_BE_ADDED")
    let message = localizer.localize("CONFIRM_YOUR_CHOICE")
    
    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
    
    let okAction = UIAlertAction(title: "OK", style: .default) { (action) in
      if self.adapter.addBookmark(item: item) {
        self.navigationItem.title = ""
      }
    }
    
    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
    
    alertController.addAction(cancelAction)
    alertController.addAction(okAction)
    
    return alertController
  }

}
