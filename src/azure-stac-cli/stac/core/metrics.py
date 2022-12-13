# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from abc import ABCMeta, abstractmethod


class Metrics(object):
    
    CONNECTION_STRING = ''
    MMAP = None
    
    def __init__(self, **kwargs):
        
        pass
        
    def _setup_open_census(self, views: any):
        """
            Bootstrap opencensus for sending metrics
            :param views: List of view to register
        """
        
        from opencensus.stats import stats as stats_module
        from opencensus.ext.azure import metrics_exporter
   
        stats = stats_module.stats
        
        view_manager = stats.view_manager
    
        exporter = metrics_exporter.new_metrics_exporter(
            connection_string=self.CONNECTION_STRING)

        view_manager.register_exporter(exporter)
        
        for view in views:
            view_manager.register_view(view)
        
        stats_recorder = stats.stats_recorder
        
        self.MMAP = stats_recorder.new_measurement_map()
        
        
    @abstractmethod
    def register_metrics(self):
        
        pass

    @abstractmethod
    def send_metrics(self):
        
        pass

def sendmetrics(func):
    '''
        Decorator to send metrics to App Insights
    '''
    
    def wrapper(*args, **kwargs):
        '''
            Wrapper to send the metrics at the end of a processor run
        '''
        
        func(*args, **kwargs)
        
        # todo: send metrics
        
        pass

    return wrapper
   