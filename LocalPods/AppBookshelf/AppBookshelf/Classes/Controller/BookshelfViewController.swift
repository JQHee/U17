//
//  BookshelfViewController.swift
//  AppBookshelf
//
//  Created by Archer on 2018/11/20.
//

import Fate
import ReactorKit

final class BookshelfViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(rgbValue: 0x30DC91)
        
    }
}

extension BookshelfViewController: View {
    
    func bind(reactor: BookshelfViewReactor) {
        
    }
}
