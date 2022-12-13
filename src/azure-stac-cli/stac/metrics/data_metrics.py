# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import os

from stac.core.metrics import Metrics


class DataMetrics(Metrics):
    
    def __init__(self, *args, **kwargs):
        
        pass
    
    def register_metrics(self):
        '''
            Register the data metrics including data size
        '''
        
        from opencensus.stats import measure as measure_module
        from opencensus.tags import tag_map as tag_map_module
        from opencensus.tags import tag_key as tag_key_module
        from opencensus.stats import view as view_module
        from opencensus.stats import aggregation as aggregation_module
        
        self.data_size_measure = measure_module.MeasureInt("data_size",
                            "Size of message being processed",
                            "bytes")
        
        data_size_view = view_module.View("Data Size",
                            "Total size of data being processed",
                            [tag_key_module.TagKey("Pod Name"),
                             tag_key_module.TagKey("Status"),
                             tag_key_module.TagKey("Processor")],
                            data_size_measure,
                            aggregation_module.SumAggregation())
        
        self._setup_open_census([data_size_view])
        
    
    def send_metrics(self, metrics: dict):
        '''
            Records the metrics to App Insights
            :param size: Metric Value
        '''
                
        from opencensus.tags import tag_map as tag_map_module
          
        pod_name = os.getenv('POD_NAME')
        
        self.MMAP.measure_int_put(self.data_size_measure,
                            metrics['size'])
                
        if pod_name is not None:
            
            tagMap = tag_map_module.TagMap()
            
            tagMap.insert("Pod Name", metrics['pod_name'])
            tagMap.insert("Status", metrics['status'])
            tagMap.insert("Processor", metrics['processor'])
            
            self.MMAP.record(tagMap)
        else:
            self.MMAP.record()