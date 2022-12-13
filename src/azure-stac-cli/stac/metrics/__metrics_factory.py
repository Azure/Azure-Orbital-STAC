from stac.metrics.data_metrics import DataMetrics
from stac.metrics.message_metrics import MessageMetrics
from stac.metrics.pod_metrics import PodMetrics
    
class MetricsFactory:
    
    
    def get_metrics_provider(self, metric_type):
        '''
            Factory to create the required Metrics class
        '''
        
        if metric_type == 'data':
            return DataMetrics
        elif metric_type == 'message':
            return MessageMetrics
        elif metric_type == 'pod':
            return PodMetrics
        

        