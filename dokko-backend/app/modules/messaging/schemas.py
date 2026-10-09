from pydantic import BaseModel, UUID4
from typing import List, Optional, Any
from datetime import datetime


class MessagingSettingsOut(BaseModel):
    module: str
    data: dict


class MessagingSettingsUpdate(BaseModel):
    module: str = "salon"
    data: dict


class TemplateOut(BaseModel):
    key: str
    label: str
    body: str
    source: str = "default"
    is_active: bool = True


class TemplateUpdate(BaseModel):
    module: str = "salon"
    key: str
    label: Optional[str] = None
    body: str


class OutboundMessageOut(BaseModel):
    id: UUID4
    recipient_name: str
    phone: str
    body: str
    status: str
    source: str
    scheduled_for: datetime

    class Config:
        from_attributes = True


class MessageBatchOut(BaseModel):
    id: UUID4
    module: str
    status: str
    created_at: Optional[datetime] = None
    messages: List[OutboundMessageOut] = []


class PendingOut(BaseModel):
    settings: MessagingSettingsOut
    batches: List[MessageBatchOut]


class HistoryOut(BaseModel):
    messages: List[OutboundMessageOut]


class BatchActionOut(BaseModel):
    batch_id: UUID4
    action: str
    updated: int
    detail: Optional[Any] = None