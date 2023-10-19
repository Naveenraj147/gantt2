public class GanttChartNew {
@AuraEnabled
    public static Map<String, Object> getChartData(String recordId, String startTime, String endTime, Integer slotSize, List<String> filterProjects, List<String> filterRoles, String filterStatus) {
        Map<String, Object> data = new Map<String, Object>();
        String query = 'SELECT Resource__c, Resource__r.Name, Resource__r.Active__c, Resource__r.Default_Role__c, Project__c, Project__r.Name, Project__r.Active__c, Project__r.Color__c, Start_Date__c, End_Date__c, Status__c, Effort__c FROM Allocation__c WHERE Start_Date__c <= :endDate AND End_Date__c >= :startDate AND (Project__c = NULL OR Project__r.Active__c = TRUE) AND Resource__r.Active__c = TRUE';
        String query2 = 'SELECT Asset__c, Asset__r.Name,Asset__r.Account.Name,Asset__r.ATS_Voltage__c,Delivery_Date__c, Pickup_Date__c,Color__c, Name from Rental_Reservation__c';
        
        List<Rental_Reservation__c> RentalReservation = new List<Rental_Reservation__c>();
        Map<String, Object> projectById = new Map<String, Object>();
        Map<String, Object> resourceById = new Map<String, Object>();
        Set<String> roles = new Set<String>();
        if (!filterRoles.isEmpty()) {
            query += ' AND Asset__r.ATS_Voltage__c IN :filterRoles';
        }
        
        RentalReservation = database.query(query2);
        
        if (String.isNotEmpty(startTime) &&  String.isNotEmpty(endTime)) {
            Date startDate = DateTime.newInstance(Long.valueOf(startTime)).date();
            
            Date endDate = DateTime.newInstance(Long.valueOf(endTime)).date();
            Integer days = startDate.daysBetween(endDate) + 1;
            slotSize = Integer.valueOf(slotSize);
            Decimal slots = days / slotSize;
        for(Rental_Reservation__c each :RentalReservation){
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
        delete new Allocation__c(Id = allocationId);
    }
}