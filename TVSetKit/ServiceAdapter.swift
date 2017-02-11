import UIKit
import SwiftyJSON

open class ServiceAdapter {
  public var spinner: Spinner?
  public var languageManager: LanguageManager?

  private let dispatchQueue = DispatchQueue(label: "Dispatch Queue", attributes: [], target: nil)

  public var currentPage = 1

  private var loading = false
  private var endOfData = false

  public var requestType: String?
  public var isContainer = false
  public var parentId: String?
  public var parentName: String?
  public var query: String?

  public var selectedItem: MediaItem?

  public var pageSize: Int!
  public var rowSize: Int!

  public var provider: String?

  private var configName: String?

  public init(configName: String) {
    languageManager = LanguageManager(configName)
  }

  open func clone() -> ServiceAdapter {
    return ServiceAdapter(configName: configName!)
  }

  open func clear() {
    currentPage = 1

    loading = false
    endOfData = false

    requestType = ""
    isContainer = false
    parentId = ""
    parentName = ""
    query = ""

    selectedItem = nil
  }

  open func nextPageAvailable(dataCount: Int, index: Int) -> Bool {
    return dataCount - index <= self.rowSize && !endOfData
  }

  open func loadData(onLoadCompleted: @escaping ([MediaItem]) -> Void) {
    if !loading {
      loading = true

      spinner?.start()

      dispatchQueue.async {
        do {
          let result = try self.load()

          self.endOfData = result.isEmpty || result.count < self.pageSize

          OperationQueue.main.addOperation() {
            if !result.isEmpty && result.count == self.pageSize {
              self.currentPage = self.currentPage + 1
            }

            self.loading = false

            self.spinner?.stop()

            if !result.isEmpty {
              onLoadCompleted(result)
            }
          }
        }
        catch {
          print("Error loading data.")

          self.loading = false

          self.spinner?.stop()
        }
      }
    }
  }

  open func load() throws -> [MediaItem] {
    return []
  }

  open func buildLayout() -> UICollectionViewFlowLayout? {
    return nil
  }

  open func getDetailsImageFrame() -> CGRect? {
    return nil
  }

//  open func setParentId(_ parentId: String) {
//    self.parentId = parentId
//  }

  open func getParentName() -> String? {
    return (parentName != nil) ? parentName : selectedItem?.name
  }

//  open func setParentName(_ parentName: String) {
//    self.parentName = parentName
//  }
//
//  open func setSelectedItem(_ item: MediaItem) {
//    selectedItem = item
//  }

  open func getUrl(_ params: [String: Any]) throws -> String? {
    return ""
  }

  open func retrieveExtraInfo(_ item: MediaItem) throws {}
  
  open func addBookmark(item: MediaItem) -> Bool {
    return true
  }
  
  open func removeBookmark(item: MediaItem) -> Bool {
    return true
  }

  open func addHistoryItem(_ item: MediaItem) {}

}
