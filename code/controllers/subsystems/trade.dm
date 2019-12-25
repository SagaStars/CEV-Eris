SUBSYSTEM_DEF(trade)
	name = "Trade"
	priority = SS_PRIORITY_SUPPLY
	flags = SS_NO_FIRE

	var/list/obj/machinery/trade_beacon/sending/beacons_sending = list()
	var/list/obj/machinery/trade_beacon/receiving/beacons_receiving = list()

	var/list/datum/trade_station/all_stations = list()
	var/list/datum/trade_station/discovered_stations = list()

/datum/controller/subsystem/trade/Initialize()
	for(var/path in subtypesof(/datum/trade_station))
		new path

	return ..()

//Returns cost of an existing object including contents
/datum/controller/subsystem/trade/proc/get_cost(atom/movable/target)
	. = 0
	for(var/atom/movable/A in target.GetAllContents(includeSelf = TRUE))
		. += A.get_item_cost(TRUE)

//Returns cost of a newly created object including contents
/datum/controller/subsystem/trade/proc/get_new_cost(path)
	var/static/list/price_cache = list()
	if(!price_cache[path])
		var/atom/movable/AM = new path
		price_cache[path] = get_cost(AM)
		qdel(AM)
	return price_cache[path]

/datum/controller/subsystem/trade/proc/get_export_cost(atom/movable/target)
	return get_cost(target) * 0.6

/datum/controller/subsystem/trade/proc/get_import_cost(path)
	return get_new_cost(path) * 1.2


/datum/controller/subsystem/trade/proc/sell(obj/machinery/trade_beacon/sending/beacon, datum/money_account/account)
	if(QDELETED(beacon))
		return

	var/points = 0

	for(var/atom/movable/AM in beacon.get_objects())
		if(AM.anchored)
			continue

		var/export_cost = get_export_cost(AM)
		if(!export_cost)
			return

		points += export_cost
		qdel(AM)

	if(!points)
		return

	beacon.activate()

	if(account)
		var/datum/money_account/A = account
		var/datum/transaction/T = new(points, account.get_name(), "Exports", "Asters Automated Trading System")
		T.apply_to(A)


/datum/controller/subsystem/trade/proc/assess_offer(obj/machinery/trade_beacon/sending/beacon, datum/trade_station/station)
	if(QDELETED(beacon) || !station)
		return

	. = list()

	for(var/atom/movable/AM in beacon.get_objects())
		if(AM.anchored || !istype(AM, station.offer_type))
			continue
		. += AM

/datum/controller/subsystem/trade/proc/fulfill_offer(obj/machinery/trade_beacon/sending/beacon, datum/money_account/account, datum/trade_station/station)
	var/list/exported = assess_offer(beacon, station)

	if(!exported || length(exported) < station.offer_amount)
		return

	exported.Cut(station.offer_amount + 1)

	for(var/atom/movable/AM in exported)
		qdel(AM)

	beacon.activate()

	if(account)
		var/datum/money_account/A = account
		var/datum/transaction/T = new(station.offer_price, account.get_name(), "Special deal", station.name)
		T.apply_to(A)

	station.generate_offer()


/datum/controller/subsystem/trade/proc/buy(obj/machinery/trade_beacon/receiving/beacon, datum/money_account/account, list/shoppinglist)
	if(QDELETED(beacon) || !account || !length(shoppinglist))
		return

	var/cost = 0
	for(var/path in shoppinglist)
		cost += get_import_cost(path) * shoppinglist[path]

	if(get_account_credits(account) < cost)
		return

	if(length(shoppinglist) == 1 && shoppinglist[shoppinglist[1]] == 1)
		var/type = shoppinglist[1]
		if(!beacon.drop(type))
			return
	else
		var/obj/structure/closet/crate/C = beacon.drop(/obj/structure/closet/crate)
		if(!C)
			return
		for(var/type in shoppinglist)
			for(var/i in 1 to shoppinglist[type])
				new type(C)

	charge_to_account(account.account_number, account.get_name(), "Purchase", "Asters Automated Trading System", cost)

	shoppinglist.Cut()