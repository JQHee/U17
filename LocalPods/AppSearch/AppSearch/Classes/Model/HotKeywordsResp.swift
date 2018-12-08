//
//  HotKeywordsResp.swift
//
//  This file is auto generated by fit.
//  Github: https://github.com/AnyOptional/fit
//
//  Copyright © 2018-present Archer. All rights reserved.
//

import YYKit

@objcMembers
class HotKeywordsResp: NSObject, YYModel {

	var data: DataBean?

	@objcMembers
	class DataBean: NSObject, YYModel {
		var message: String?
		var stateCode: Int = 0
		var returnData: ReturnDataBean?

		@objcMembers
		class ReturnDataBean: NSObject, YYModel {
			var hotItems: [HotItemsBean]?

			@objcMembers
			class HotItemsBean: NSObject, YYModel {
				var name: String?
				var bgColor: String?
				var comic_id: String?
			}

			var defaultSearch: String?

			static func modelContainerPropertyGenericClass() -> [String : Any]? {
    			return ["hotItems" : HotItemsBean.self]
			}
		}

	}

	var code: Int = 0
}
