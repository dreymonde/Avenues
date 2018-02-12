import UIKit
import PlaygroundSupport
import Avenues

final class EntryTableViewCell : UITableViewCell {
    
    let entryLabel = UILabel()
    let entryImageView = UIImageView()
    
}

struct Entry {
    let text: String
    let imageURL: URL
}

final class ExampleTableViewController : UITableViewController {
    
    var entries: [Entry] = []
    
    let avenue = UIImageAvenue() // Avenue<URL, UIImage>
    
    override func viewDidLoad() {
        tableView.register(EntryTableViewCell.self, forCellReuseIdentifier: "example")
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entries.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "example", for: indexPath) as! EntryTableViewCell
        let entry = entries[indexPath.row]
        cell.entryLabel.text = entry.text
        avenue.register(cell.entryImageView, for: entry.imageURL)
    }
    
}


