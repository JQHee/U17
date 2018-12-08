//
//  U17SearchViewController.swift
//  AppSearch
//
//  Created by Archer on 2018/12/4.
//

import Fate
import RxSwift
import RxCocoa
import RxSwiftExt
import ReactorKit
import RxAppState
import RxDataSources

class U17SearchViewController: UIViewController {
    
    private lazy var searchBar: U17SearchBar = {
        let width = view.width - 70
        let height = 25.toCGFloat()
        let searchBar = U17SearchBar(size: CGSize(width: width, height: height))
        navigationItem.titleView = searchBar
        return searchBar
    }()
    
    private lazy var tableView: UITableView = {
        let v = UITableView(frame: .zero, style: .grouped)
        v.estimatedRowHeight = 40
        v.separatorStyle = .none
        v.backgroundColor = .white
        v.keyboardDismissMode = .onDrag
        v.fate.register(cellClass: U17HotSearchCell.self)
        v.fate.register(cellClass: U17HistorySearchCell.self)
        v.fate.register(cellClass: U17KeywordRelativeCell.self)
        if #available(iOS 11, *) {
            v.contentInsetAdjustmentBehavior = .never
        }
        return v
    }()
    
    private lazy var placeholderView = U17PlaceholderView()
    
    private lazy var dataSource = tableViewSectionedReloadDataSource()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        buildNavbar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchBar.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 缓存写到本地
        U17KeywordsCache.synchronize()
        searchBar.resignFirstResponder()
    }
    
    deinit { NSLog("\(className()) is deallocating...") }
}

extension U17SearchViewController {
    // MARK: 取消搜索
    @objc private func popViewController() {
        self.navigationController?.popViewController(animated: false)
    }
}

extension U17SearchViewController: View {
    func bind(reactor: U17SearchViewReactor) {
        
        // MARK: 设置代理
        tableView.rx.setDelegate(self).disposed(by: disposeBag)
        
        // MARK: 占位图点击
        placeholderView.rx.tap
            // 点击的时候切换到加载状态(菊花转)
            .do(onNext: { [weak self] _ in self?.placeholderView.state = .loading })
            .map { _ in Reactor.Action.getKeywords }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        // MARK: 占位图状态变化
        reactor.state
            .map { $0.placeholderState }
            .bind(to: placeholderView.rx.state)
            .disposed(by: disposeBag)
        
        // MARK: 加载数据
        // NOTE: searchBar.rx.text在bind时会发出当前的text
        // searchBar默认是没有文字的 所以flatMap之后会触发getKeywords
        // 这里的就不需要了
        //        rx.viewDidLoad
        //            .map { Reactor.Action.getKeywords }
        //            .bind(to: reactor.action)
        //            .disposed(by: disposeBag)
        
        // MARK: 绑定数据源
        reactor.state
            .map { $0.sections }
            .filterEmpty()
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
        
        // MARK: 设置占位文字
        reactor.state
            .map { $0.placeholderText }
            .filterNil()
            .bind(to: searchBar.rx.placeholderText)
            .disposed(by: disposeBag)
        
        // MARK: 清空时加载热门关键词
        // NOTE: searchBar.rx.text监听的时text editing event
        // 并不包含手动赋值 所以这里清除时需要手动刷新
        searchBar.rx.clear
            .do(onNext: { [weak self] in
                // 标记正在加载
                self?.placeholderView.state = .loading
            }).map { Reactor.Action.getKeywords }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        // MARK: 搜索
        searchBar
            .rx.text.orEmpty
            // 不重复搜索
            .distinctUntilChanged()
            // 在0.5s内不连续搜索
            .throttle(0.5, scheduler: MainScheduler.instance)
            .flatMap({ [weak self] (keyword) -> Observable<Reactor.Action> in
                // 标记正在加载
                self?.placeholderView.state = .loading
                // 如果是删光了就加载热门关键词
                // 否则就开始搜索
                let action = keyword.isBlank ? Reactor.Action.getKeywords
                                             : Reactor.Action.getKeywordRelative(keyword)
                return .just(action)
            }).bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        // MARK: cell点击
        tableView
            .rx.modelSelected(U17SearchSectionItem.self)
            .subscribeNext(weak: self) { (self) in
                return { (sectionItem) in
                    switch sectionItem {
                    // 在cell.rx.tap里处理
                    case .hot: break
                    case .history(item: let item):
                        self.tapKeyword(item.state.rawValue)
                    case .relative(item: let item):
                        self.tapKeyword(item.state.rawValue.name)
                    }
                }
            }.disposed(by: disposeBag)
        
        // MARK: 处理出错
        reactor.state
            .map { $0.error }
            .filterNil()
            .subscribeNext(weak: self) { (self) in
                return { error in
                    SwiftyHUD.show(error.message)
                }
            }.disposed(by: disposeBag)
    }
    
    private func tableViewSectionedReloadDataSource() -> RxTableViewSectionedReloadDataSource<U17SearchSection> {
        return RxTableViewSectionedReloadDataSource(configureCell: { [weak self] (ds, tv, ip, sectionItem) in
            switch sectionItem {
            case .hot(item: let display):
                let cell: U17HotSearchCell = tv.fate.dequeueReusableCell(for: ip)
                self?.configure(hotSearchCell: cell, display: display)
                return cell
                
            case .history(item: let display):
                let cell: U17HistorySearchCell = tv.fate.dequeueReusableCell(for: ip)
                cell.display = display
                return cell
                
            case .relative(item: let display):
                let cell: U17KeywordRelativeCell = tv.fate.dequeueReusableCell(for: ip)
                cell.display = display
                return cell
            }
        })
    }
    
    private func configure(hotSearchCell cell: U17HotSearchCell, display: U17HotSearchCellDisplay) {
        cell.disposeBag = DisposeBag()
        cell.display = display
        cell.rx.tap
            .subscribeNext(weak: self, { (self) in
                return { (keyword) in
                    self.tapKeyword(keyword)
                }
            }).disposed(by: cell.disposeBag)
    }
    
    private func tapKeyword(_ keyword: String?) {
        // 存历史搜索
        U17KeywordsCache.store(keyword)
        // TODO: 进详情

    }
}

extension U17SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {        
        switch dataSource[indexPath] {
        case .hot(item: let display):
            return tableView.fate.heightForRowAt(indexPath, cellClass: U17HotSearchCell.self, configuration: { (cell) in
                self.configure(hotSearchCell: cell, display: display)
            })
            
        // 写定好了 这个就不自动算了
        default: return 45
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        var mode: U17SearchHeaderView.DisplayMode?
        switch dataSource[section] {
        case .hot: mode = .hot
        case .history: mode = .history
        case .relative: mode = nil // 搜索结果不需要headerView
        }
        guard let displayMode = mode else { return nil }
        let view = U17SearchHeaderView()
        view.disposeBag = DisposeBag()
        view.displayMode = displayMode
        view.rx.event
            .flatMap { (displayMode) -> Observable<Reactor.Action> in
                switch displayMode {
                case .hot: return .just(Reactor.Action.refreshHotKeywords)
                case .history: return .just(Reactor.Action.removeHistoryKeywords)
                }
            }.bind(to: reactor!.action) // It's safe to force-unwrap here
            .disposed(by: view.disposeBag)
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch dataSource[section] {
        case .hot, .history: return 30
        case .relative: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
}

extension U17SearchViewController {
    func buildNavbar() {
        navigationItem.hidesBackButton = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "取消", style: .plain,
                                                            target: self, action: #selector(popViewController))
        let titleTextAttributes: [NSAttributedString.Key : Any] = [.font : UIFont.systemFont(ofSize: 15),
                                                                   .foregroundColor : U17def.gray_AAAAAA]
        navigationItem.rightBarButtonItem?.setTitleTextAttributes(titleTextAttributes, for: .normal)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes(titleTextAttributes, for: .highlighted)
    }
    
    func buildUI() {
        view.backgroundColor = .white
        automaticallyAdjustsScrollViewInsets = false
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.top.equalToSuperview()
            make.left.right.bottom.equalToSuperview()
        }
        
        placeholderView.contentInset = UIEdgeInsets(top: -fate.fullNavbarHeight,
                                                    left: 0, bottom: 0, right: 0)
        view.addSubview(placeholderView)
        placeholderView.snp.makeConstraints { (make) in
            make.edges.equalTo(tableView)
        }
    }
}