public class GanttChartNew {
    @AuraEnabled
    public static Map<String, Object> getChartData(String recordId, String startTime, String endTime, Integer slotSize, List<String> filterProjects, List<String> filterRoles, String filterStatus, String filterMonth) {
        Map<String, Object> data = new Map<String, Object>();
        Date day = System.Today();
        String query2 = 'SELECT Asset__c, Asset__r.Name,Asset__r.Account.Name,Asset__r.ATS_Voltage__c,Asset__r.kW__c,Delivery_Date__c, Pickup_Date__c,Color__c, Name from Rental_Reservation__c where Pickup_Date__c>= :day';
        
        List<Rental_Reservation__c> RentalReservation = new List<Rental_Reservation__c>();
        Map<String, Object> projectById = new Map<String, Object>();
        Map<String, Object> resourceById = new Map<String, Object>();
        Set<String> roles = new Set<String>();
        Integer intFilterRoles;
        Integer intFilterMonths;
        
        System.debug('filterRoles :: '+ filterRoles);
        System.debug('filterStatus :: '+ filterStatus);
        System.debug('filterMonth :: '+ filterMonth);
        if (!filterRoles.isEmpty()) {
            query2 += ' AND Asset__r.ATS_Voltage__c IN :filterRoles';
        }
        if (String.isNotEmpty(filterStatus)) {
            intFilterRoles =  integer.valueOf(filterStatus);
            query2 += ' AND Asset__r.kW__c <= :intFilterRoles';
       }
       if (String.isNotEmpty(filterMonth)) {
            intFilterMonths =  integer.valueOf(filterMonth);
            query2 += ' AND CALENDAR_MONTH(Pickup_Date__c) = :intFilterMonths';
       }
        
        RentalReservation = database.query(query2);
        
        if (String.isNotEmpty(startTime) &&  String.isNotEmpty(endTime)) {
            Date startDate = DateTime.newInstance(Long.valueOf(startTime)).date();
            
            Date endDate = DateTime.newInstance(Long.valueOf(endTime)).date();
            Integer days = startDate.daysBetween(endDate) + 1;
            slotSize = Integer.valueOf(slotSize);
            Decimal slots = days / slotSize;
            
            for(Rental_Reservation__c each :RentalReservation){
                system.debug('Reantal Reservation :: '+each);
                if(resourceById.containskey(each.Asset__c)){
                    
                    Map<String, Object> resource = (Map<String, Object>)resourceById.get(each.Asset__c);
                    Map<String, Object> allocationsByProject = (Map<String, Object>)resource.get('allocationsByProject');
                    
                    Decimal left = Decimal.valueOf(startDate.daysBetween(each.Delivery_Date__c)) / slotSize;
                    left = left.round(System.RoundingMode.FLOOR);
                    
                    Decimal right = Decimal.valueOf(startDate.daysBetween(each.Pickup_Date__c)) / slotSize;
                    right = right.round(System.RoundingMode.FLOOR);
                    
                    List<Object> projectAllocation = (List<Object>)allocationsByProject.get(each.Asset__c);
                    projectAllocation.add(new Map<String, Object> {
                        'Id' => each.Id,
                            'Start_Date__c' => each.Delivery_Date__c,
                            'End_Date__c' => each.Pickup_Date__c,
                            'Status__c' => 'Active',
                            'Effort__c' => 'High',
                            'projectName' => each.Name,
                            'color' => each.Color__c,
                            'left' => left,
                            'right' => right
                            });
                }
                else{
                    resourceById.put(each.Asset__c, new Map<String, Object> {
                        'Id' => each.Asset__c,
                            'Name' => each.Asset__r.Name,
                            'Default_Role__c' => each.Asset__r.Account.Name,
                            'allocationsByProject' => new Map<String, Object>()
                            });
                    Map<String, Object> resource = (Map<String, Object>)resourceById.get(each.Asset__c);
                    Map<String, Object> allocationsByProject = (Map<String, Object>)resource.get('allocationsByProject');
                    
                    Decimal left = Decimal.valueOf(startDate.daysBetween(each.Delivery_Date__c)) / slotSize;
                    left = left.round(System.RoundingMode.FLOOR);
                    
                    Decimal right = Decimal.valueOf(startDate.daysBetween(each.Pickup_Date__c)) / slotSize;
                    right = right.round(System.RoundingMode.FLOOR);
                    
                    if (!allocationsByProject.containsKey(each.Asset__c)) {
                        allocationsByProject.put(each.Asset__c, new List<Object>());
                    }
                    
                    List<Object> projectAllocation = (List<Object>)allocationsByProject.get(each.Asset__c);
                    system.debug('each :: '+each);
                    system.debug('left :: '+left);
                    system.debug('right :: '+right);
                    projectAllocation.add(new Map<String, Object> {
                        'Id' => each.Id,
                            'Start_Date__c' => each.Delivery_Date__c,
                            'End_Date__c' => each.Pickup_Date__c,
                            'Status__c' => 'Active',
                            'Effort__c' => 'High',
                            'projectName' => each.Name,
                            'color' => each.Color__c,
                            'left' => left,
                            'right' => right
                            });
                }
                roles.add(each.Asset__r.ATS_Voltage__c);
            } 
        }
        
        data.put('projects', projectById.values());
        data.put('resources', resourceById.values());
        data.put('roles', roles);
        System.debug('resources :: '+data.get('resources'));
        return data;
    }
    
    @AuraEnabled
    public static List<Object> getResources() {
        List<Object> resources = new List<Object>();
        
        for (Asset r : [SELECT Id, Name, Account.Name
                        FROM Asset
                        ORDER BY Name]) {
                            resources.add(new Map<String, Object> {
                                'Id' => r.Id,
                                    'Name' => r.Name,
                                    'Default_Role__c' => r.Account.Name
                                    });
                        }
        
        return resources;
    }
    
    @AuraEnabled
    public static List<Project__c> getProjects() {
        return [SELECT Id, Name
                FROM Project__c
                WHERE Active__c = true
                ORDER BY Name];
    }
    
    @AuraEnabled
    public static void saveAllocation(Id allocationId, Id projectId, Id resourceId, String effort, String status, String startDate, String endDate) {
        Rental_Reservation__c allocation = new Rental_Reservation__c(
            Delivery_Date__c = DateTime.newInstance(Long.valueOf(startDate)).date(),
            Pickup_Date__c = DateTime.newInstance(Long.valueOf(endDate)).date()
        );
        
        // update allocation
        if (null != allocationId) {
            allocation.Id = allocationId;
        } else {
            /*   if (null != projectId) {
allocation.Project__c = projectId;
}*/
            
            //  allocation.Resource__c = resourceId;
        }
        
        if (String.isNotEmpty(effort)) {
            //  allocation.Effort__c = effort;
        }
        if (String.isNotEmpty(status)) {
            //  allocation.Status__c = status;
            
            // remove project
            if ('Unavailable' == status) {
                //  allocation.Project__c = null;
            }
        }
        
        upsert allocation;
    }
    
    @AuraEnabled
    public static void deleteAllocation(Id allocationId) {
        delete new Rental_Reservation__c(Id = allocationId);
    }
}